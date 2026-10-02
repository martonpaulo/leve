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

    /// Whether a full-screen alert on screen stays: its event still blocks, has not ended, and alerts
    /// are not paused. An alert that outlived its event would also hold back the next one.
    public static func keepsFullScreen(eventID: String, events: [AttendedEvent], now: Date, paused: Bool) -> Bool {
        guard !paused, let item = events.first(where: { $0.event.id == eventID }) else { return false }
        return item.attention.blocksScreen && !item.event.hasEnded(at: now)
    }

    /// The reminders that have fired: their time passed more than two seconds ago. A reminder is
    /// scheduled at least a second ahead, so the margin keeps a replan from cancelling one that is
    /// about to fire.
    public static func delivered(fireDates: [String: Date], now: Date) -> Set<String> {
        let firedBefore = now.addingTimeInterval(-2)
        return Set(fireDates.filter { $0.value < firedBefore }.keys)
    }

    /// Whether to say the time now: on an interval boundary, inside the speech hours, not paused,
    /// someone at the Mac, no alerting event happening, and not already said this minute.
    public static func shouldSayTime(
        now: Date,
        interval: SpeechInterval,
        hours: SpeechHours,
        paused: Bool,
        away: Bool,
        events: [AttendedEvent],
        lastSpokenMinute: Date?,
        calendar: Calendar
    ) -> Bool {
        guard interval.isBoundary(now, calendar: calendar), hours.contains(now, calendar: calendar),
            !paused, !away, !isInAlertingEvent(events: events, now: now)
        else { return false }
        return calendar.dateInterval(of: .minute, for: now)?.start != lastSpokenMinute
    }

    /// The spoken time stays quiet while an alerting event is happening.
    public static func isInAlertingEvent(events: [AttendedEvent], now: Date) -> Bool {
        events.contains { $0.attention.isAlerting && !$0.event.isAllDay && $0.event.isOngoing(at: now) }
    }
}
