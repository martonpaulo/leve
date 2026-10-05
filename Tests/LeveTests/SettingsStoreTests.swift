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

    @Test func pausingMediaIsOffUntilTurnedOnAndRestoreDefaultsTurnsItOff() {
        withDefaults { defaults in
            #expect(!Preferences(defaults: defaults).pauseMediaOnBreak)
            Preferences(defaults: defaults).pauseMediaOnBreak = true
            let preferences = Preferences(defaults: defaults)
            #expect(preferences.pauseMediaOnBreak)
            preferences.breakSound = false
            preferences.debugMenu = true
            preferences.restoreDefaults()
            #expect(!preferences.pauseMediaOnBreak)
            #expect(!Preferences(defaults: defaults).pauseMediaOnBreak)
            #expect(preferences.breakSound)
            #expect(preferences.debugMenu)
        }
    }

    @Test func restoreDefaultsKeepsThePauseAndTheDebugMenu() {
        withDefaults { defaults in
            let preferences = Preferences(defaults: defaults)
            preferences.countdownMinutes = 60
            preferences.showFreeUntil = false
            preferences.setRule(.ignore, for: "work")
            preferences.debugMenu = true
            let until = Date.now.addingTimeInterval(600)
            preferences.pause(until: until)
            preferences.restoreDefaults()
            #expect(preferences.countdownMinutes == 30)
            #expect(preferences.showFreeUntil)
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

    /// Dismissing a holiday that spans several days hides it for the day it was dismissed only.
    @Test func aDismissedMultiDayAllDayEventReturnsTheNextDay() {
        withDefaults { defaults in
            let monday = Date(timeIntervalSince1970: 1_790_640_000)  // 2026-09-29 00:00 UTC
            let tuesdayNoon = monday.addingTimeInterval(36 * 3600)
            let vacation = CalendarEvent(
                id: CalendarEvent.occurrenceID(eventIdentifier: "vacation", start: monday), title: "Vacation",
                start: monday, end: monday.addingTimeInterval(5 * 86400), isAllDay: true, calendarID: "home",
                calendarTitle: "Home", link: nil)
            OverrideStore(defaults: defaults, calendar: utc, now: tuesdayNoon).set(
                .hidden, for: vacation, now: tuesdayNoon)
            // Tuesday first: opening a store prunes, so Wednesday's would drop the choice.
            let laterTuesday = OverrideStore(
                defaults: defaults, calendar: utc, now: tuesdayNoon.addingTimeInterval(3600))
            #expect(laterTuesday.override(for: vacation) == .hidden)
            let wednesday = OverrideStore(
                defaults: defaults, calendar: utc, now: monday.addingTimeInterval(2 * 86400 + 60))
            #expect(wednesday.override(for: vacation) == nil)
        }
    }

    @Test func aHiddenSeriesHidesEveryRepeatUntilShown() {
        withDefaults { defaults in
            let store = OverrideStore(defaults: defaults, calendar: utc, now: .distantPast)
            let today = event(at: Date(timeIntervalSince1970: 1_790_000_000))
            let nextWeek = event(at: today.start.addingTimeInterval(7 * 86400))
            store.hideSeries(of: today)
            let reopened = OverrideStore(defaults: defaults, calendar: utc, now: nextWeek.start)
            #expect(reopened.override(for: nextWeek) == .hidden)
            // Shown again from Settings, not from the menu's "Show Hidden".
            #expect(reopened.hiddenCount(among: [nextWeek]) == 0)
            reopened.showSeries(nextWeek.seriesID)
            #expect(reopened.override(for: nextWeek) == nil)
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

@MainActor @Suite struct TimeLeftTests {
    private let now = Date(timeIntervalSince1970: 1_790_683_200)  // Tuesday 2026-09-29 12:00 UTC

    @Test func minutesWithinTheHour() {
        #expect(Copy.timeLeft(40, end: now.addingTimeInterval(40 * 60), now: now, calendar: utc) == "40 min left")
    }

    @Test func theEndTimeForALongEvent() {
        let text = Copy.timeLeft(180, end: now.addingTimeInterval(3 * 3600), now: now, calendar: utc)
        #expect(text.hasPrefix("until ") && !text.contains("min"))
    }

    @Test func theDayForAnEventThatEndsAnotherDay() {
        let end = now.addingTimeInterval(3 * 86400)
        #expect(Copy.timeLeft(4320, end: end, now: now, calendar: utc) == "until Fri")
    }
}

/// The menu bar never names the event; the menu's own status line still does (#4).
@MainActor @Suite struct MenuBarTextTests {
    private let end = Date.now.addingTimeInterval(20 * 60)

    @Test func anUpcomingEventShowsOnlyTheCountdown() {
        #expect(Copy.menuBarStatus(.upcoming(title: "Standup", minutes: 12)) == "in 12 min")
    }

    @Test func anOngoingEventShowsOnlyTheTimeLeft() {
        #expect(Copy.menuBarStatus(.ongoing(title: "Standup", minutesLeft: 20, end: end)) == "20 min left")
        let long = Copy.menuBarStatus(
            .ongoing(title: "Workshop", minutesLeft: 180, end: Date.now.addingTimeInterval(3 * 3600)))
        #expect(long.hasPrefix("until ") && !long.contains("Workshop"))
    }

    @Test func theMenuStillNamesTheEvent() {
        #expect(Copy.status(.upcoming(title: "Standup", minutes: 12)) == "Standup in 12 min")
    }
}
