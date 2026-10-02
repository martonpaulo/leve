import Foundation
import LeveKit

/// A fixed day in UTC, so every test reads the same clock.
enum Fixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// 2026-10-03 at `hour`:`minute` UTC.
    static func at(_ hour: Int, _ minute: Int = 0) -> Date {
        let components = DateComponents(year: 2026, month: 10, day: 3, hour: hour, minute: minute)
        return calendar.date(from: components) ?? .distantPast
    }

    static func event(
        _ title: String,
        from start: Date,
        minutes: Int = 30,
        allDay: Bool = false,
        link: MeetingLink? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: CalendarEvent.occurrenceID(eventIdentifier: title, start: start),
            title: title,
            start: start,
            end: start.addingTimeInterval(Double(minutes) * 60),
            isAllDay: allDay,
            calendarID: "work",
            calendarTitle: "Work",
            link: link
        )
    }

    static func attended(
        _ event: CalendarEvent,
        rule: CalendarRule = .everything,
        override: EventOverride? = nil
    ) -> AttendedEvent {
        AttendedEvent(event: event, attention: .resolve(rule: rule, override: override))
    }
}
