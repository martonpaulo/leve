import Foundation
import LeveKit
import Observation

/// Per-event choices made from the menu or the full-screen alert: alerts off, hidden, or no full
/// screen. Each is keyed by the event and its day, so it survives the event moving to another time
/// that day, and is dropped once its event has ended.
@Observable
final class OverrideStore {
    private struct Entry: Codable {
        let override: EventOverride
        let eventEnd: Date
    }

    /// v1 keyed entries by the occurrence id, which changes when an event moves.
    private static let legacyKey = "leve.eventOverrides.v1"
    private static let key = "leve.eventOverrides.v2"
    private static let seriesKey = "leve.hiddenSeries.v1"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    private var entries: [String: Entry]
    /// Repeating events hidden for good, by series id, with the title Settings shows to undo it.
    private(set) var hiddenSeries: [String: String]
    /// Changes on every write, so an observer can replan without reading each entry.
    private(set) var revision = 0

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: Date = .now) {
        self.defaults = defaults
        self.calendar = calendar
        var loaded = Self.decode(defaults.data(forKey: Self.key))
        for (occurrenceID, entry) in Self.decode(defaults.data(forKey: Self.legacyKey)) {
            loaded[CalendarEvent.choiceKey(fromOccurrenceID: occurrenceID, calendar: calendar)] = entry
        }
        defaults.removeObject(forKey: Self.legacyKey)
        entries = loaded
        hiddenSeries = defaults.dictionary(forKey: Self.seriesKey) as? [String: String] ?? [:]
        prune(now: now)
    }

    func override(for event: CalendarEvent) -> EventOverride? {
        if hiddenSeries[event.seriesID] != nil { return .hidden }
        return entries[event.choiceKey(calendar: calendar)]?.override
    }

    /// Hides every occurrence of a repeating event, today's and future ones, until Settings shows it.
    func hideSeries(of event: CalendarEvent) {
        hiddenSeries[event.seriesID] = event.title
        saveSeries()
    }

    func showSeries(_ seriesID: String) {
        hiddenSeries[seriesID] = nil
        saveSeries()
    }

    /// A choice lasts until its event ends; on an all-day event it lasts until today ends, so a
    /// holiday dismissed on Tuesday comes back on Wednesday.
    func set(_ override: EventOverride?, for event: CalendarEvent, now: Date = .now) {
        var expiry = event.end
        if event.isAllDay, let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            expiry = min(expiry, tomorrow)
        }
        entries[event.choiceKey(calendar: calendar)] = override.map { Entry(override: $0, eventEnd: expiry) }
        save()
    }

    /// How many of `events` were hidden one by one: the menu offers to show them again. A hidden
    /// series comes back from Settings instead, so it is not counted.
    func hiddenCount(among events: [CalendarEvent]) -> Int {
        events.filter { entries[$0.choiceKey(calendar: calendar)]?.override == .hidden }.count
    }

    func unhideAll() {
        entries = entries.filter { $0.value.override != .hidden }
        save()
    }

    /// Drops the choices of events that have ended; a long-running Leve calls it at each new day.
    func prune(now: Date) {
        entries = entries.filter { $0.value.eventEnd > now }
        save()
    }

    private func saveSeries() {
        revision += 1
        defaults.set(hiddenSeries, forKey: Self.seriesKey)
    }

    private func save() {
        revision += 1
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
    }

    private static func decode(_ data: Data?) -> [String: Entry] {
        data.flatMap { try? JSONDecoder().decode([String: Entry].self, from: $0) } ?? [:]
    }
}
