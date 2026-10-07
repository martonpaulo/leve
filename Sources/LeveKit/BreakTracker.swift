import Foundation

/// How long Leve lets the owner work before it asks for a break, and how long the break lasts.
public struct BreakSchedule: Sendable, Equatable {
    public let workMinutes: Int
    public let breakMinutes: Int

    public init(workMinutes: Int, breakMinutes: Int) {
        self.workMinutes = workMinutes
        self.breakMinutes = breakMinutes
    }
}

/// What the minute tick knows when it asks whether a break is due.
public struct BreakContext: Sendable, Equatable {
    /// Seconds since the last keyboard or pointer input.
    public let idleSeconds: Double
    /// In a meeting: an alerting event is happening, a call holds the microphone, or the event's
    /// full screen is up. Meeting time counts as work, and idle time in a meeting is not a break.
    public let isBusy: Bool
    /// An alerting event starts before a break would end, so the break waits until after it.
    public let eventStartsSoon: Bool
    /// Alerts are paused; time still counts, and the break waits.
    public let isPaused: Bool

    public init(idleSeconds: Double, isBusy: Bool, eventStartsSoon: Bool, isPaused: Bool) {
        self.idleSeconds = idleSeconds
        self.isBusy = isBusy
        self.eventStartsSoon = eventStartsSoon
        self.isPaused = isPaused
    }
}

/// Counts the time worked since the last break. Time away from the Mac at least as long as a
/// break counts as one; a meeting never shows a break, but its time counts, so a break that falls
/// due during it appears as soon as it ends.
public struct BreakTracker: Sendable, Equatable {
    public private(set) var workStart: Date
    /// "Later" left the break waiting in the menu bar until the owner takes it (#19).
    public private(set) var isPending = false
    /// The previous tick. A gap at least as long as a break means the Mac slept or Leve was not
    /// running, which is time away, whatever the input idle time says.
    private var lastTick: Date?

    public init(now: Date) {
        workStart = now
    }

    /// Updates the count for this tick and returns true when the break should appear now.
    public mutating func isDue(now: Date, context: BreakContext, schedule: BreakSchedule) -> Bool {
        let breakSeconds = Double(schedule.breakMinutes * 60)
        let gap = lastTick.map { now.timeIntervalSince($0) } ?? 0
        lastTick = now
        if gap >= breakSeconds || (!context.isBusy && context.idleSeconds >= breakSeconds) {
            restart(now: now)
            return false
        }
        guard !context.isBusy, !context.eventStartsSoon, !context.isPaused else { return false }
        if isPending { return false }
        return now.timeIntervalSince(workStart) >= Double(schedule.workMinutes * 60)
    }

    /// The break was taken or skipped, or the owner was away for one: the count starts again and
    /// a pending break is gone.
    public mutating func restart(now: Date) {
        workStart = now
        isPending = false
    }

    /// "Later": the break never comes back on its own; it waits in the menu bar until the owner
    /// takes it, with the worked time still counting (#19).
    public mutating func `defer`() {
        isPending = true
    }

    /// True when an alerting, timed event starts within `minutes`: a break then would collide
    /// with the event's own alerts.
    public static func eventStartsSoon(events: [AttendedEvent], now: Date, minutes: Int) -> Bool {
        let limit = now.addingTimeInterval(Double(minutes * 60))
        return events.contains {
            $0.attention.isAlerting && !$0.event.isBackground && $0.event.start > now && $0.event.start <= limit
        }
    }
}
