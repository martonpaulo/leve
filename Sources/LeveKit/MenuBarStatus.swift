import Foundation

/// What the menu bar text says. It answers one question: am I in an event, is one coming, or am
/// I free, and until when.
public enum MenuBarStatus: Sendable, Equatable {
    /// No alerting event is left today. Background events (all day, out of office, long) never count.
    case clear
    /// The next alerting event starts later than the countdown window.
    case freeUntil(Date)
    /// The next alerting event starts within the countdown window.
    case upcoming(title: String, minutes: Int)
    /// An alerting event is happening now. `end` lets a long event say when it ends instead of
    /// counting hundreds of minutes.
    case ongoing(title: String, minutesLeft: Int, end: Date)

    /// Whether the menu bar item writes this status next to its icon. "Nothing else today" never
    /// does, and "Free until …" only when the owner keeps it on (#10). The accessibility label
    /// always carries the text.
    public func showsText(freeUntil: Bool) -> Bool {
        switch self {
        case .clear: false
        case .freeUntil: freeUntil
        case .upcoming, .ongoing: true
        }
    }

    /// - Parameters:
    ///   - events: today's events with their attention; only alerting, timed events count.
    ///   - countdownMinutes: how close an event must be before its countdown replaces "free until".
    public static func resolve(events: [AttendedEvent], now: Date, countdownMinutes: Int) -> MenuBarStatus {
        let timed = events.filter { $0.attention.isAlerting && !$0.event.isBackground }.map(\.event)

        if let current = timed.filter({ $0.isOngoing(at: now) }).min(by: { $0.end < $1.end }) {
            return .ongoing(
                title: current.title, minutesLeft: max(1, Int((current.end.timeIntervalSince(now) / 60).rounded(.up))),
                end: current.end)
        }
        guard let next = timed.filter({ $0.start > now }).min(by: { $0.start < $1.start }) else {
            return .clear
        }
        let minutes = max(1, next.minutesUntilStart(from: now))
        if minutes <= countdownMinutes {
            return .upcoming(title: next.title, minutes: minutes)
        }
        return .freeUntil(next.start)
    }
}
