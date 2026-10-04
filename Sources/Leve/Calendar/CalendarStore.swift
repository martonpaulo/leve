import AppKit
import EventKit
import LeveKit
import OSLog
import Observation

/// Reads today's events from the calendars on this Mac. Events stay owned by Calendar; Leve keeps
/// a copy for the current day only and never writes to EventKit.
@Observable
final class CalendarStore {
    enum Access: Equatable {
        case notDetermined
        case granted
        case denied
    }

    struct CalendarInfo: Identifiable, Hashable {
        let id: String
        let title: String
        let source: String
        let color: NSColor
    }

    private(set) var access: Access = .notDetermined
    private(set) var events: [CalendarEvent] = []
    private(set) var calendars: [CalendarInfo] = []

    func color(for calendarID: String) -> NSColor {
        calendars.first { $0.id == calendarID }?.color ?? .secondaryLabelColor
    }
    /// Called after every reload, so the scheduler can replan alerts.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private let logger = Logger(subsystem: "com.martonpaulo.leve", category: "calendar")
    @ObservationIgnored private var observer: NSObjectProtocol?

    init() {
        access = Self.currentAccess()
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    func requestAccessIfNeeded() async {
        guard access == .notDetermined else { return }
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
        }
        access = Self.currentAccess()
        reload()
    }

    /// Reads the permission again; a change, such as access granted in System Settings, reloads.
    func refreshAccess() {
        if Self.currentAccess() != access {
            reload()
        }
    }

    /// Reloads today's events, and tells the scheduler only when something changed, so a burst
    /// of store notifications does not replan the same day again and again.
    func reload(now: Date = .now) {
        let previous = (access, events, calendars)
        access = Self.currentAccess()
        guard access == .granted else {
            events = []
            calendars = []
            if previous != (access, events, calendars) { onChange?() }
            return
        }
        let eventCalendars = store.calendars(for: .event)
        calendars =
            eventCalendars
            .map {
                CalendarInfo(
                    id: $0.calendarIdentifier, title: $0.title, source: $0.source.title,
                    color: NSColor(cgColor: $0.cgColor) ?? .secondaryLabelColor)
            }
            .sorted { ($0.source, $0.title) < ($1.source, $1.title) }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
        // Timed events in the first hour of tomorrow come too, for their alerts only: at 23:55 an
        // event at 00:05 must already be known. The menu lists today's events alone.
        let fetchEnd = dayEnd.addingTimeInterval(Self.lookahead)
        let predicate = store.predicateForEvents(withStart: dayStart, end: fetchEnd, calendars: eventCalendars)
        events = store.events(matching: predicate)
            .filter { $0.status != .canceled && !Self.declinedByMe($0) }
            .filter { $0.startDate < dayEnd || !$0.isAllDay }
            .map(Self.makeEvent)
            .sorted(by: CalendarEvent.displayOrder)
        if previous != (access, events, calendars) {
            onChange?()
        }
    }

    static let lookahead: TimeInterval = 60 * 60

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private static func declinedByMe(_ event: EKEvent) -> Bool {
        event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }

    private static func makeEvent(_ event: EKEvent) -> CalendarEvent {
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
        let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CalendarEvent(
            id: CalendarEvent.occurrenceID(eventIdentifier: identifier, start: event.startDate),
            title: (title?.isEmpty == false ? title : nil) ?? Copy.untitledEvent,
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            calendarID: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            link: MeetingLink.resolve(url: event.url, location: event.location, notes: event.notes),
            availability: availability(event.availability),
            isRecurring: event.hasRecurrenceRules
        )
    }

    private static func availability(_ value: EKEventAvailability) -> Availability {
        switch value {
        case .busy: .busy
        case .free: .free
        case .tentative: .tentative
        case .unavailable: .unavailable
        default: .unknown
        }
    }
}
