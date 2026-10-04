import Foundation

/// How an event marks the owner's time in Calendar, from EventKit's availability.
public enum Availability: String, Sendable, Hashable {
    case busy, free, tentative, unknown
    /// Out of office.
    case unavailable
}

/// One occurrence of a calendar event, copied out of EventKit so the logic never touches it.
public struct CalendarEvent: Sendable, Hashable, Identifiable {
    /// Stable for one occurrence: a recurring event yields a different id on each day.
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendarID: String
    public let calendarTitle: String
    public let link: MeetingLink?
    public let availability: Availability
    /// One occurrence of a repeating event; all of them share `seriesID`.
    public let isRecurring: Bool

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarID: String,
        calendarTitle: String,
        link: MeetingLink?,
        availability: Availability = .busy,
        isRecurring: Bool = false
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.link = link
        self.availability = availability
        self.isRecurring = isRecurring
    }

    /// Events this long are backdrops, such as a conference or a working-hours block, not meetings.
    public static let backgroundDuration: TimeInterval = 4 * 60 * 60

    /// Listed, but never a meeting: all day, out of office, or at least four hours long. It sends no
    /// alert, keeps no menu bar countdown, and neither quiets the voice nor holds a break.
    public var isBackground: Bool {
        isAllDay || availability == .unavailable || end.timeIntervalSince(start) >= Self.backgroundDuration
    }

    /// The same for every occurrence of a repeating event: the id without its start.
    public var seriesID: String { Self.split(id).base }

    /// The id for one occurrence of a possibly recurring event.
    public static func occurrenceID(eventIdentifier: String, start: Date) -> String {
        "\(eventIdentifier)@\(Int(start.timeIntervalSince1970))"
    }

    /// The key for a choice made from the menu or the full screen: the event and its day, not its
    /// start time, so a choice survives the event moving to another time that day.
    public func choiceKey(calendar: Calendar) -> String {
        "\(Self.split(id).base)@\(Self.day(start, calendar: calendar))"
    }

    /// Converts a key stored before choice keys existed (`<event>@<start seconds>`).
    public static func choiceKey(fromOccurrenceID id: String, calendar: Calendar) -> String {
        let parts = split(id)
        guard let seconds = parts.seconds else { return id }
        return "\(parts.base)@\(day(Date(timeIntervalSince1970: seconds), calendar: calendar))"
    }

    private static func split(_ id: String) -> (base: String, seconds: Double?) {
        guard let at = id.lastIndex(of: "@"), let seconds = Double(id[id.index(after: at)...]) else {
            return (id, nil)
        }
        return (String(id[..<at]), seconds)
    }

    private static func day(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Whole minutes until the start, rounded up and never negative: 90 seconds is 2 minutes, and
    /// a started event is 0. Every surface that says "in N min" reads it.
    public func minutesUntilStart(from now: Date) -> Int {
        max(0, Int((start.timeIntervalSince(now) / 60).rounded(.up)))
    }

    /// The menu order: all-day events first, then by start.
    public static func displayOrder(_ lhs: CalendarEvent, _ rhs: CalendarEvent) -> Bool {
        (lhs.isAllDay ? 0 : 1, lhs.start) < (rhs.isAllDay ? 0 : 1, rhs.start)
    }

    public func isOngoing(at now: Date) -> Bool {
        start <= now && now < end
    }

    public func hasEnded(at now: Date) -> Bool {
        end <= now
    }
}
