import Foundation
import LeveKit
import Testing

@testable import Leve

/// A throwaway defaults suite per test, removed afterwards, so no test touches real preferences.
@MainActor
private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
    let name = "leve.tests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: name) else { return }
    defer { defaults.removePersistentDomain(forName: name) }
    try body(defaults)
}

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}

private func event(at start: Date) -> CalendarEvent {
    CalendarEvent(
        id: CalendarEvent.occurrenceID(eventIdentifier: "standup", start: start), title: "Standup", start: start,
        end: start.addingTimeInterval(1800), isAllDay: false, calendarID: "work", calendarTitle: "Work", link: nil)
}

@MainActor @Suite struct PreferencesTests {
    @Test func aFreshInstallStartsWithTheDefaults() {
        withDefaults { defaults in
            let preferences = Preferences(defaults: defaults)
            #expect(preferences.reminderLeadMinutes == 5)
            #expect(preferences.fullScreenLeadMinutes == 1)
            #expect(preferences.countdownMinutes == 30)
            #expect(preferences.speechInterval == .halfHour)
            #expect(preferences.spokenAlertMinutes == 2)
        }
    }

    @Test func offSurvivesARelaunch() {
        withDefaults { defaults in
            Preferences(defaults: defaults).reminderLeadMinutes = nil
            #expect(Preferences(defaults: defaults).reminderLeadMinutes == nil)
        }
    }

    @Test func aStoredValueOutsideTheOptionsFallsBack() {
        withDefaults { defaults in
            defaults.set(7, forKey: "leve.reminderLeadMinutes.v1")
            defaults.set(99, forKey: "leve.spokenAlertMinutes.v1")
            defaults.set(45, forKey: "leve.speechIntervalMinutes.v1")
            let preferences = Preferences(defaults: defaults)
            #expect(preferences.reminderLeadMinutes == 5)
            #expect(preferences.spokenAlertMinutes == 2)
            #expect(preferences.speechInterval == .halfHour)
        }
    }

    @Test func restoreDefaultsKeepsThePauseAndTheDebugMenu() {
        withDefaults { defaults in
            let preferences = Preferences(defaults: defaults)
            preferences.countdownMinutes = 60
            preferences.setRule(.ignore, for: "work")
            preferences.debugMenu = true
            let until = Date.now.addingTimeInterval(600)
            preferences.pause(until: until)
            preferences.restoreDefaults()
            #expect(preferences.countdownMinutes == 30)
            #expect(preferences.rule(for: "work") == .everything)
            #expect(preferences.debugMenu)
            #expect(preferences.pausedUntil == until)
        }
    }
}

@MainActor @Suite struct OverrideStoreTests {
    @Test func aChoiceSurvivesTheEventMovingThatDay() {
        withDefaults { defaults in
            let store = OverrideStore(defaults: defaults, calendar: utc, now: .distantPast)
            let start = Date(timeIntervalSince1970: 1_790_000_000)
            store.set(.silenced, for: event(at: start))
            #expect(store.override(for: event(at: start.addingTimeInterval(900))) == .silenced)
        }
    }

    @Test func choicesOfEndedEventsAreDropped() {
        withDefaults { defaults in
            let start = Date(timeIntervalSince1970: 1_790_000_000)
            OverrideStore(defaults: defaults, calendar: utc, now: .distantPast).set(.hidden, for: event(at: start))
            let later = OverrideStore(defaults: defaults, calendar: utc, now: start.addingTimeInterval(3600))
            #expect(later.override(for: event(at: start)) == nil)
        }
    }

    @Test func unhideAllKeepsTheOtherChoices() {
        withDefaults { defaults in
            let store = OverrideStore(defaults: defaults, calendar: utc, now: .distantPast)
            let first = event(at: Date(timeIntervalSince1970: 1_790_000_000))
            let second = CalendarEvent(
                id: CalendarEvent.occurrenceID(eventIdentifier: "review", start: first.start), title: "Review",
                start: first.start, end: first.end, isAllDay: false, calendarID: "work", calendarTitle: "Work",
                link: nil)
            store.set(.hidden, for: first)
            store.set(.silenced, for: second)
            store.unhideAll()
            #expect(store.override(for: first) == nil)
            #expect(store.override(for: second) == .silenced)
        }
    }

    /// v1 stored choices by occurrence id; they move to the event-and-day key once.
    @Test func versionOneChoicesMigrate() throws {
        try withDefaults { defaults in
            let start = Date(timeIntervalSince1970: 1_790_000_000)
            let legacy = [
                event(at: start).id: [
                    "override": "silenced", "eventEnd": start.addingTimeInterval(1800).timeIntervalSinceReferenceDate,
                ]
            ]
            defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "leve.eventOverrides.v1")
            let store = OverrideStore(defaults: defaults, calendar: utc, now: .distantPast)
            #expect(store.override(for: event(at: start)) == .silenced)
            #expect(defaults.data(forKey: "leve.eventOverrides.v1") == nil)
        }
    }
}
