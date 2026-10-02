import Foundation

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

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarID: String,
        calendarTitle: String,
        link: MeetingLink?
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.link = link
    }

    /// The id for one occurrence of a possibly recurring event.
    public static func occurrenceID(eventIdentifier: String, start: Date) -> String {
        "\(eventIdentifier)@\(Int(start.timeIntervalSince1970))"
    }

    public func isOngoing(at now: Date) -> Bool {
        start <= now && now < end
    }

    public func hasEnded(at now: Date) -> Bool {
        end <= now
    }
}
