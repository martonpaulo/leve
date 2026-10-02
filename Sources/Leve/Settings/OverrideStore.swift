import Foundation
import LeveKit
import Observation

/// Per-occurrence choices made from the menu or the full-screen alert: silenced, hidden, or no
/// full screen. Each entry remembers when its event ends, and entries for past events are dropped.
@Observable
final class OverrideStore {
    private struct Entry: Codable {
        let override: EventOverride
        let eventEnd: Date
    }

    private static let key = "leve.eventOverrides.v1"

    @ObservationIgnored private let defaults: UserDefaults
    private var entries: [String: Entry]

    init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults
        let data = defaults.data(forKey: Self.key)
        let decoded = data.flatMap { try? JSONDecoder().decode([String: Entry].self, from: $0) } ?? [:]
        entries = decoded.filter { $0.value.eventEnd > now }
        save()
    }

    func override(for eventID: String) -> EventOverride? {
        entries[eventID]?.override
    }

    func set(_ override: EventOverride?, for event: CalendarEvent) {
        entries[event.id] = override.map { Entry(override: $0, eventEnd: event.end) }
        save()
    }

    /// Hidden events of today, newest choice not tracked: the menu offers to show them all again.
    func hiddenCount(among eventIDs: Set<String>) -> Int {
        entries.filter { eventIDs.contains($0.key) && $0.value.override == .hidden }.count
    }

    func unhideAll() {
        entries = entries.filter { $0.value.override != .hidden }
        save()
    }

    /// Changes on every write, so an observer can replan without reading each entry.
    private(set) var revision = 0

    private func save() {
        revision += 1
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
