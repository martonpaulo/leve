import Foundation

/// A notification to deliver before an event.
public struct PlannedReminder: Sendable, Equatable {
    public let event: CalendarEvent
    public let fireDate: Date
}

/// Decides when notifications and the full-screen alert happen. Pure, so every rule is tested.
public enum AlertPlanner {
    /// How long after its start an event can still raise the full-screen alert, for a Mac that was
    /// asleep or locked when the alert was due.
    public static let fullScreenGrace: TimeInterval = 5 * 60

    /// One reminder per alerting, timed event that has not started yet. A reminder whose time
    /// already passed fires now, so launching Leve two minutes before a meeting still warns.
    /// `delivered` holds the events whose reminder already fired; a later replan skips them.
    public static func reminders(
        events: [AttendedEvent],
        now: Date,
        leadMinutes: Int?,
        delivered: Set<String>
    ) -> [PlannedReminder] {
        guard let leadMinutes else { return [] }
        return events.compactMap { item in
            let event = item.event
            guard item.attention.isAlerting, !event.isAllDay, event.start > now, !delivered.contains(event.id) else {
                return nil
            }
            let fireDate = max(event.start.addingTimeInterval(-Double(leadMinutes) * 60), now)
            return PlannedReminder(event: event, fireDate: fireDate)
        }
    }

    /// The events whose full-screen alert is due now and has not been shown or closed yet.
    public static func dueFullScreen(
        events: [AttendedEvent],
        now: Date,
        leadMinutes: Int?,
        alreadyHandled: Set<String>
    ) -> [CalendarEvent] {
        guard let leadMinutes else { return [] }
        return events.compactMap { item in
            let event = item.event
            guard item.attention.blocksScreen, !event.isAllDay, !alreadyHandled.contains(event.id) else {
                return nil
            }
            let opens = event.start.addingTimeInterval(-Double(leadMinutes) * 60)
            let closes = min(event.start.addingTimeInterval(fullScreenGrace), event.end)
            return (opens <= now && now < closes) ? event : nil
        }
        .sorted { $0.start < $1.start }
    }

    /// The events whose spoken warning is due: `leadMinutes` before an alerting, timed event, and
    /// only until it starts. Each event is spoken once.
    public static func dueSpokenAlerts(
        events: [AttendedEvent],
        now: Date,
        leadMinutes: Int?,
        alreadySpoken: Set<String>
    ) -> [CalendarEvent] {
        guard let leadMinutes else { return [] }
        return events.compactMap { item in
            let event = item.event
            guard item.attention.isAlerting, !event.isAllDay, !alreadySpoken.contains(event.id) else { return nil }
            let opens = event.start.addingTimeInterval(-Double(leadMinutes) * 60)
            return (opens <= now && now < event.start) ? event : nil
        }
        .sorted { $0.start < $1.start }
    }

    /// The spoken time stays quiet while an alerting event is happening.
    public static func isInAlertingEvent(events: [AttendedEvent], now: Date) -> Bool {
        events.contains { $0.attention.isAlerting && !$0.event.isAllDay && $0.event.isOngoing(at: now) }
    }
}
