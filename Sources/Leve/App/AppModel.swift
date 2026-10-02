import AppKit
import LeveKit
import OSLog
import Observation

/// Ties the calendar, the settings and the three kinds of alert together. A single minute tick
/// drives the menu bar text, the full-screen alert and the spoken time; notifications are
/// scheduled ahead with the system and replanned whenever the inputs change.
@Observable
final class AppModel {
    let preferences: Preferences
    let overrides: OverrideStore
    let calendar: CalendarStore
    let reminders: ReminderScheduler
    private(set) var now = Date.now
    /// Events made by the Debug menu. They live in memory only and never reach Calendar.
    private(set) var simulatedEvents: [CalendarEvent] = []

    @ObservationIgnored let alert = FullScreenAlert()
    @ObservationIgnored private let speaker = TimeSpeaker()
    @ObservationIgnored private let logger = Logger(subsystem: "com.martonpaulo.leve", category: "model")
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var handledFullScreen: Set<String> = []
    @ObservationIgnored private var lastSpokenMinute: Date?
    @ObservationIgnored private var wasPaused = false
    /// When each planned reminder fires; one whose time passed counts as delivered.
    @ObservationIgnored private var reminderFireDates: [String: Date] = [:]
    @ObservationIgnored private var replanTask: Task<Void, Never>?
    /// The spoken time is pointless with the displays asleep or another user at the Mac.
    @ObservationIgnored private var isAway = false
    @ObservationIgnored private var started = false

    init(
        preferences: Preferences = Preferences(),
        overrides: OverrideStore = OverrideStore(),
        calendar: CalendarStore = CalendarStore(),
        reminders: ReminderScheduler = ReminderScheduler()
    ) {
        self.preferences = preferences
        self.overrides = overrides
        self.calendar = calendar
        self.reminders = reminders
        alert.onJoin = { [weak self] event in self?.join(event) }
        alert.onNeverForEvent = { [weak self] event in self?.overrides.set(.noFullScreen, for: event) }
    }

    // MARK: Derived state

    /// Today's calendar events plus any simulated ones, in start order.
    var events: [CalendarEvent] {
        guard !simulatedEvents.isEmpty else { return calendar.events }
        return (calendar.events + simulatedEvents)
            .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
    }

    var attendedEvents: [AttendedEvent] {
        events.map { event in
            AttendedEvent(
                event: event,
                attention: .resolve(
                    rule: preferences.rule(for: event.calendarID),
                    override: overrides.override(for: event.id)
                )
            )
        }
    }

    var status: MenuBarStatus {
        .resolve(events: attendedEvents, now: now, countdownMinutes: preferences.countdownMinutes)
    }

    var isPaused: Bool { preferences.isPaused(at: now) }

    /// Listed events that have not ended, all-day ones first.
    var menuEvents: [AttendedEvent] {
        attendedEvents.filter { $0.attention.isListed && !$0.event.hasEnded(at: now) }
    }

    var hiddenCount: Int {
        overrides.hiddenCount(among: Set(events.map(\.id)))
    }

    // MARK: Lifecycle

    func start() async {
        guard !started else { return }
        started = true
        calendar.onChange = { [weak self] in self?.replan() }
        observeInputs()
        observeSystem()
        await calendar.requestAccessIfNeeded()
        await reminders.requestAuthorization()
        calendar.reload()
        startTicking()
    }

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        let refresh: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didWakeNotification),
            (NotificationCenter.default, .NSSystemTimeZoneDidChange),
            (NotificationCenter.default, .NSCalendarDayChanged),
        ]
        for (center, name) in refresh {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.calendar.reload()
                    self?.tick()
                }
            }
        }
        let away: [(Notification.Name, Bool)] = [
            (NSWorkspace.screensDidSleepNotification, true),
            (NSWorkspace.screensDidWakeNotification, false),
            (NSWorkspace.sessionDidResignActiveNotification, true),
            (NSWorkspace.sessionDidBecomeActiveNotification, false),
        ]
        for (name, value) in away {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isAway = value }
            }
        }
    }

    private func startTicking() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                let current = Date.now
                let nextMinute =
                    Calendar.current.nextDate(
                        after: current,
                        matching: DateComponents(second: 0),
                        matchingPolicy: .nextTime
                    ) ?? current.addingTimeInterval(60)
                // A little past the boundary, so the minute has turned when the tick reads the clock.
                try? await Task.sleep(for: .seconds(nextMinute.timeIntervalSince(current) + 0.2))
                self?.tick()
            }
        }
    }

    func tick() {
        let previous = now
        now = .now
        if !Calendar.current.isDate(previous, inSameDayAs: now) {
            calendar.reload(now: now)
        }
        if wasPaused && !isPaused {
            preferences.resume()
        }
        checkFullScreen()
        speakIfDue()
    }

    /// Replans whenever a setting, an override or the pause changes.
    private func observeInputs() {
        withObservationTracking {
            _ = preferences.reminderLeadMinutes
            _ = preferences.fullScreenLeadMinutes
            _ = preferences.urgentDelivery
            _ = preferences.calendarRules
            _ = preferences.pausedUntil
            _ = overrides.revision
            _ = simulatedEvents
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.replan()
                self?.observeInputs()
            }
        }
    }

    func replan() {
        now = .now
        wasPaused = isPaused
        // A reminder fires a second after it is scheduled at the earliest, so a two-second margin
        // keeps a replan from cancelling one that is just about to fire.
        let firedBefore = now.addingTimeInterval(-2)
        let delivered = Set(reminderFireDates.filter { $0.value < firedBefore }.keys)
        let planned =
            isPaused
            ? []
            : AlertPlanner.reminders(
                events: attendedEvents, now: now, leadMinutes: preferences.reminderLeadMinutes, delivered: delivered)
        let todayIDs = Set(events.map(\.id))
        reminderFireDates = reminderFireDates.filter { delivered.contains($0.key) && todayIDs.contains($0.key) }
        for reminder in planned {
            reminderFireDates[reminder.event.id] = reminder.fireDate
        }
        let urgent = preferences.urgentDelivery && reminders.supportsUrgentDelivery == true
        let start = now
        logger.info(
            "Replanned: \(planned.count, privacy: .public) reminders, \(self.events.count, privacy: .public) events today"
        )
        // One replacement at a time: two interleaved ones could remove each other's requests.
        replanTask = Task { [previous = replanTask, reminders] in
            await previous?.value
            await reminders.replace(with: planned, urgent: urgent, now: start)
        }
        checkFullScreen()
    }

    // MARK: Full screen and speech

    private func checkFullScreen() {
        if let shown = alert.event {
            let stillBlocks = attendedEvents.contains { $0.event.id == shown.id && $0.attention.blocksScreen }
            if !stillBlocks || isPaused {
                alert.dismissSilently()
            }
            return
        }
        guard !isPaused else { return }
        let due = AlertPlanner.dueFullScreen(
            events: attendedEvents,
            now: now,
            leadMinutes: preferences.fullScreenLeadMinutes,
            alreadyHandled: handledFullScreen
        )
        guard let event = due.first else { return }
        handledFullScreen.insert(event.id)
        logger.notice("Full-screen alert for an event at \(event.start, privacy: .public)")
        alert.present(event)
    }

    private func speakIfDue() {
        let calendar = Calendar.current
        guard preferences.speechInterval.isBoundary(now, calendar: calendar),
            !isPaused,
            !isAway,
            !AlertPlanner.isInAlertingEvent(events: attendedEvents, now: now)
        else { return }
        let minute = calendar.dateInterval(of: .minute, for: now)?.start
        guard minute != lastSpokenMinute else { return }
        lastSpokenMinute = minute
        speaker.speak(now, voiceIdentifier: preferences.voiceIdentifier)
    }

    func previewSpeech() {
        speaker.speak(.now, voiceIdentifier: preferences.voiceIdentifier)
    }

    // MARK: Menu actions

    func join(_ event: CalendarEvent) {
        guard let url = event.link?.url else { return }
        NSWorkspace.shared.open(url)
    }

    func toggleSilence(_ event: CalendarEvent) {
        let isSilenced = overrides.override(for: event.id) == .silenced
        overrides.set(isSilenced ? nil : .silenced, for: event)
    }

    func hide(_ event: CalendarEvent) {
        overrides.set(.hidden, for: event)
    }

    func pause(minutes: Int) {
        preferences.pause(until: Date.now.addingTimeInterval(Double(minutes) * 60))
    }

    func pauseUntilTomorrow() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        preferences.pause(until: calendar.date(byAdding: .day, value: 1, to: today) ?? today)
    }
}

// MARK: - Debug menu

extension AppModel {
    static let debugCalendarID = "leve.debug"

    /// A fake event that starts in two whole minutes and lasts five, with a call link, so the
    /// countdown, the notification and the full screen can be watched end to end.
    func simulateEvent() {
        let calendar = Calendar.current
        let minute = calendar.dateInterval(of: .minute, for: .now)?.start ?? .now
        simulatedEvents.append(makeSimulatedEvent(start: minute.addingTimeInterval(2 * 60), minutes: 5))
    }

    func showFullScreenNow() {
        alert.present(makeSimulatedEvent(start: Date.now.addingTimeInterval(60), minutes: 5))
    }

    func sendTestNotification() {
        let event = makeSimulatedEvent(start: Date.now.addingTimeInterval(5 * 60), minutes: 5)
        Task { await reminders.sendNow(event) }
    }

    func clearSimulatedEvents() {
        simulatedEvents = []
    }

    private func makeSimulatedEvent(start: Date, minutes: Int) -> CalendarEvent {
        let number = simulatedEvents.count + 1
        return CalendarEvent(
            id: "\(Self.debugCalendarID).\(UUID().uuidString)",
            title: Copy.simulatedEventTitle(number),
            start: start,
            end: start.addingTimeInterval(Double(minutes) * 60),
            isAllDay: false,
            calendarID: Self.debugCalendarID,
            calendarTitle: Copy.debug,
            link: URL(string: "https://meet.google.com/").map { MeetingLink(url: $0, provider: .googleMeet) }
        )
    }
}
