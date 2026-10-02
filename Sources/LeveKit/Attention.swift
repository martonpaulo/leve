import Foundation

/// How much attention Leve gives to the events of one calendar. One choice per calendar.
public enum CalendarRule: String, Sendable, Hashable, CaseIterable, Codable {
    /// Countdown, notification and full screen.
    case everything
    /// Countdown and notification, never full screen.
    case noFullScreen
    /// Listed in the menu only: no countdown, no alert, and the spoken time continues.
    case menuOnly
    /// Not shown at all.
    case ignore

    public static let defaultRule: CalendarRule = .everything
}

/// What the owner chose for one occurrence from the menu or the full-screen alert.
public enum EventOverride: String, Sendable, Hashable, Codable {
    /// Stays in the menu, but no countdown, alert or full screen.
    case silenced
    /// Not shown and no alerts.
    case hidden
    /// Alerts as usual, but no full screen.
    case noFullScreen
}

/// The resolved attention for one event, from its calendar's rule and its own override.
public struct EventAttention: Sendable, Equatable {
    public let isListed: Bool
    /// Counts for the menu bar text, sends a notification and quiets the spoken time.
    public let isAlerting: Bool
    public let blocksScreen: Bool

    public static func resolve(rule: CalendarRule, override: EventOverride?) -> EventAttention {
        let ruleListed = rule != .ignore
        let ruleAlerting = rule == .everything || rule == .noFullScreen
        switch override {
        case .hidden:
            return EventAttention(isListed: false, isAlerting: false, blocksScreen: false)
        case .silenced:
            return EventAttention(isListed: ruleListed, isAlerting: false, blocksScreen: false)
        case .noFullScreen:
            return EventAttention(isListed: ruleListed, isAlerting: ruleAlerting, blocksScreen: false)
        case nil:
            return EventAttention(isListed: ruleListed, isAlerting: ruleAlerting, blocksScreen: rule == .everything)
        }
    }
}

/// An event together with its resolved attention: the input every planner reads.
public struct AttendedEvent: Sendable, Equatable {
    public let event: CalendarEvent
    public let attention: EventAttention

    public init(event: CalendarEvent, attention: EventAttention) {
        self.event = event
        self.attention = attention
    }
}
