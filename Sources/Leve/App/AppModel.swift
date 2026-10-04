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
    @ObservationIgnored let breakScreen = BreakScreen()
    @ObservationIgnored private var breakTracker = BreakTracker(now: .now)
    static let breakLaterMinutes = 5
    /// The Debug menu's events take the next of Calendar's colors each time, to compare them.
    @ObservationIgnored private var debugColorIndex = 0
    private static let debugColors: [NSColor] = [
        .systemIndigo, .systemOrange, .systemGreen, .systemPink, .systemYellow, .systemTeal, .systemPurple,
        .systemBrown, .systemRed, .systemBlue,
    ]
    /// Opens the Settings window; the app delegate, which owns it, sets this.
    @ObservationIgnored var openSettings: () -> Void = {}
    @ObservationIgnored private let speaker = TimeSpeaker()
    @ObservationIgnored private let logger = Logger(subsystem: "com.martonpaulo.leve", category: "model")
    /// Every break decision, so "why did the break (not) appear at 15:00?" has an answer in the log.
    @ObservationIgnored private let breakLog = Logger(subsystem: "com.martonpaulo.leve", category: "breaks")
    /// The last state written to `breakLog`; a state is written once, when it changes, not every minute.
    @ObservationIgnored private var loggedBreakState = ""
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var handledFullScreen: Set<String> = []
    @ObservationIgnored private var lastSpokenMinute: Date?
    @ObservationIgnored private var spokenAlerts: Set<String> = []
    @ObservationIgnored private var wasPaused = false
    /// When each planned reminder fires; one whose time passed counts as delivered.
    @ObservationIgnored private var reminderFireDates: [String: Date] = [:]
    @ObservationIgnored private var replanTask: Task<Void, Never>?
    /// The spoken time is pointless with the displays asleep or another user at the Mac.
    @ObservationIgnored private var isAway = false
    @ObservationIgnored private var started = false
    /// The day today's events were loaded for. `now` also moves in `replan()`, so comparing it
    /// with the previous `now` could miss midnight when a replan lands just after it.
    @ObservationIgnored private var currentDay = Calendar.current.startOfDay(for: .now)

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
        let color: (String) -> NSColor = { [weak self, calendar] id in
            guard id == Self.debugCalendarID, let self else { return calendar.color(for: id) }
            return Self.debugColors[debugColorIndex % Self.debugColors.count]
        }
        reminders.calendarColor = color
        alert.tint = { color($0.calendarID) }
        breakScreen.onDone = { [weak self] in self?.endBreak("taken") }
        breakScreen.onSkip = { [weak self] in self?.endBreak("skipped") }
        breakScreen.onLater = { [weak self] in
            self?.breakTracker.postpone(now: .now, minutes: Self.breakLaterMinutes)
            self?.breakLog.notice("Break postponed \(Self.breakLaterMinutes, privacy: .public) min")
        }
        alert.onJoin = { [weak self] event in self?.join(event) }
        alert.onNeverForEvent = { [weak self] event in self?.overrides.set(.noFullScreen, for: event) }
    }

    // MARK: Derived state

    /// Today's calendar events plus any simulated ones, in start order.
    var events: [CalendarEvent] {
        guard !simulatedEvents.isEmpty else { return calendar.events }
        return (calendar.events + simulatedEvents).sorted(by: CalendarEvent.displayOrder)
    }

    var attendedEvents: [AttendedEvent] {
        events.map { event in
            AttendedEvent(
                event: event,
                attention: .resolve(
                    rule: preferences.rule(for: event.calendarID),
                    override: overrides.override(for: event)
                )
            )
        }
    }

    var status: MenuBarStatus {
        .resolve(events: attendedEvents, now: now, countdownMinutes: preferences.countdownMinutes)
    }

    var isPaused: Bool { preferences.isPaused(at: now) }

    /// Listed timed events that have not ended.
    var menuEvents: [AttendedEvent] {
        attendedEvents.filter { $0.attention.isListed && !$0.event.isAllDay && !$0.event.hasEnded(at: now) }
    }

    /// Listed all-day events, for their own menu section; empty when they are turned off.
    var allDayEvents: [AttendedEvent] {
        guard preferences.showAllDayEvents else { return [] }
        return attendedEvents.filter { $0.attention.isListed && $0.event.isAllDay && !$0.event.hasEnded(at: now) }
    }

    var hiddenCount: Int {
        overrides.hiddenCount(among: events)
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
        replan()
        startTicking()
    }

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        let refresh: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didWakeNotification),
            (NotificationCenter.default, .NSSystemTimeZoneDidChange),
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
        now = .now
        // The one midnight trigger: a new day reloads today's events and forgets yesterday's.
        let today = Calendar.current.startOfDay(for: now)
        if today != currentDay {
            currentDay = today
            overrides.prune(now: now)
            calendar.reload(now: now)
        }
        // Access granted later in System Settings is picked up within a minute.
        if calendar.access != .granted {
            calendar.refreshAccess()
        }
        if wasPaused && !isPaused {
            preferences.resume()
        }
        checkFullScreen()
        checkBreak()
        speakUpcomingIfDue()
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
        let delivered = AlertPlanner.delivered(fireDates: reminderFireDates, now: now)
        let planned =
            isPaused
            ? []
            : AlertPlanner.reminders(
                events: attendedEvents, now: now, leadMinutes: preferences.reminderLeadMinutes, delivered: delivered)
        let todayIDs = Set(events.map(\.id))
        reminderFireDates = reminderFireDates.filter { delivered.contains($0.key) && todayIDs.contains($0.key) }
        handledFullScreen.formIntersection(todayIDs)
        spokenAlerts.formIntersection(todayIDs)
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
            if !AlertPlanner.keepsFullScreen(eventID: shown.id, events: attendedEvents, now: now, paused: isPaused) {
                alert.dismissSilently()
            } else {
                return
            }
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
        // The event wins; its time counts as work, so the break comes back after it.
        breakScreen.dismissSilently()
        alert.present(event)
    }

    /// Shows the break once enough work has passed, never over an event, a call or the pause.
    private func checkBreak() {
        guard let schedule = preferences.breakSchedule else {
            // Turning breaks on starts a fresh count.
            breakTracker.restart(now: now)
            logBreakState("off")
            return
        }
        guard !breakScreen.isVisible else { return }
        let inEvent = AlertPlanner.isInAlertingEvent(events: attendedEvents, now: now)
        let inCall = ActivityMonitor.isMicrophoneInUse
        let context = BreakContext(
            idleSeconds: ActivityMonitor.idleSeconds,
            isBusy: alert.isVisible || inEvent || inCall,
            eventStartsSoon: BreakTracker.eventStartsSoon(
                events: attendedEvents, now: now, minutes: schedule.breakMinutes),
            isPaused: isPaused
        )
        let countStart = breakTracker.workStart
        let due = breakTracker.isDue(now: now, context: context, schedule: schedule)
        let worked = Int(now.timeIntervalSince(countStart) / 60)
        if breakTracker.workStart != countStart {
            breakLog.notice(
                "Away \(Int(context.idleSeconds / 60), privacy: .public) min after \(worked, privacy: .public) min of work: count restarted"
            )
        }
        logBreakState(
            Self.breakState(
                context: context, inEvent: inEvent, inCall: inCall, fullScreen: alert.isVisible,
                notBefore: breakTracker.notBefore, now: now))
        guard due else { return }
        breakLog.notice("Break shown after \(worked, privacy: .public) min of work")
        breakScreen.present(
            minutes: schedule.breakMinutes, laterMinutes: Self.breakLaterMinutes,
            sound: preferences.breakSound)
    }

    private func endBreak(_ how: String) {
        breakTracker.restart(now: .now)
        breakLog.notice("Break \(how, privacy: .public): count restarted")
    }

    /// Why the break is waiting, or "counting" when nothing holds it.
    private static func breakState(
        context: BreakContext, inEvent: Bool, inCall: Bool, fullScreen: Bool, notBefore: Date?, now: Date
    ) -> String {
        if fullScreen { return "waiting: event full screen" }
        if inEvent { return "waiting: in an event" }
        if inCall { return "waiting: call (microphone in use)" }
        if context.eventStartsSoon { return "waiting: an event starts soon" }
        if context.isPaused { return "waiting: alerts paused" }
        if let notBefore, now < notBefore { return "waiting: later" }
        return "counting"
    }

    private func logBreakState(_ state: String) {
        guard state != loggedBreakState else { return }
        loggedBreakState = state
        let worked = Int(now.timeIntervalSince(breakTracker.workStart) / 60)
        breakLog.notice("Break \(state, privacy: .public), \(worked, privacy: .public) min of work so far")
    }

    /// Says "Standup in 2 minutes" before an alerting event, at any hour, unless alerts are paused.
    private func speakUpcomingIfDue() {
        guard !isPaused, let minutes = preferences.spokenAlertMinutes else { return }
        let due = AlertPlanner.dueSpokenAlerts(
            events: attendedEvents, now: now, leadMinutes: minutes, alreadySpoken: spokenAlerts)
        for event in due {
            spokenAlerts.insert(event.id)
            let left = max(1, event.minutesUntilStart(from: now))
            speaker.speakUpcoming(event, minutes: left, voiceIdentifier: preferences.voiceIdentifier)
        }
    }

    private func speakIfDue() {
        // The break asks for quiet; the time is said again at the next boundary after it.
        guard !breakScreen.isVisible else { return }
        let calendar = Calendar.current
        guard
            AlertPlanner.shouldSayTime(
                now: now, interval: preferences.speechInterval, hours: preferences.speechHours, paused: isPaused,
                away: isAway, events: attendedEvents, lastSpokenMinute: lastSpokenMinute, calendar: calendar)
        else { return }
        lastSpokenMinute = calendar.dateInterval(of: .minute, for: now)?.start
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

    /// Turns this event's alerts off, or back on.
    func toggleAlerts(_ event: CalendarEvent) {
        let isOff = overrides.override(for: event) == .silenced
        overrides.set(isOff ? nil : .silenced, for: event)
    }

    /// Stops the full screen for this event, or brings it back.
    func toggleFullScreen(_ event: CalendarEvent) {
        let isOff = overrides.override(for: event) == .noFullScreen
        overrides.set(isOff ? nil : .noFullScreen, for: event)
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

    /// The event joins the simulated ones, so the next tick finds it and keeps the alert up.
    func showFullScreenNow() {
        let event = makeSimulatedEvent(start: Date.now.addingTimeInterval(60), minutes: 5)
        debugColorIndex += 1
        simulatedEvents.append(event)
        handledFullScreen.insert(event.id)
        alert.present(event)
    }

    func showBreakNow() {
        breakScreen.present(
            minutes: preferences.breakLengthMinutes, laterMinutes: Self.breakLaterMinutes,
            sound: preferences.breakSound)
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
