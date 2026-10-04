import Foundation
import LeveKit
import Testing

@Suite struct AlertPlannerTests {
    private let standup = Fixture.event("Standup", from: Fixture.at(10))

    @Test func remindsLeadMinutesBefore() {
        let planned = AlertPlanner.reminders(
            events: [Fixture.attended(standup)], now: Fixture.at(8), leadMinutes: 5, delivered: [])
        #expect(planned.map(\.fireDate) == [Fixture.at(9, 55)])
    }

    @Test func aLateLaunchStillWarnsNow() {
        let now = Fixture.at(9, 58)
        let planned = AlertPlanner.reminders(
            events: [Fixture.attended(standup)], now: now, leadMinutes: 5, delivered: [])
        #expect(planned.map(\.fireDate) == [now])
    }

    /// A replan after the reminder fired (a calendar edit, a settings change) must not fire it again.
    @Test func aDeliveredReminderIsNotPlannedAgain() {
        let planned = AlertPlanner.reminders(
            events: [Fixture.attended(standup)], now: Fixture.at(9, 57), leadMinutes: 5,
            delivered: [standup.id])
        #expect(planned.isEmpty)
    }

    @Test func noReminderWhenOffStartedOrQuiet() {
        #expect(
            AlertPlanner.reminders(
                events: [Fixture.attended(standup)], now: Fixture.at(8), leadMinutes: nil, delivered: []
            ).isEmpty)
        #expect(
            AlertPlanner.reminders(
                events: [Fixture.attended(standup)], now: Fixture.at(10), leadMinutes: 5, delivered: []
            ).isEmpty)
        let quiet = [Fixture.attended(standup, rule: .menuOnly)]
        #expect(AlertPlanner.reminders(events: quiet, now: Fixture.at(8), leadMinutes: 5, delivered: []).isEmpty)
    }

    @Test(arguments: [(9, 58, false), (9, 59, true), (10, 4, true), (10, 5, false)])
    func fullScreenWindow(hour: Int, minute: Int, due: Bool) {
        let result = AlertPlanner.dueFullScreen(
            events: [Fixture.attended(standup)],
            now: Fixture.at(hour, minute),
            leadMinutes: 1,
            alreadyHandled: []
        )
        #expect(result.isEmpty == !due)
    }

    @Test func fullScreenShowsOncePerEvent() {
        let result = AlertPlanner.dueFullScreen(
            events: [Fixture.attended(standup)],
            now: Fixture.at(9, 59),
            leadMinutes: 1,
            alreadyHandled: [standup.id]
        )
        #expect(result.isEmpty)
    }

    @Test func fullScreenRespectsTheRule() {
        let result = AlertPlanner.dueFullScreen(
            events: [Fixture.attended(standup, rule: .noFullScreen)],
            now: Fixture.at(9, 59),
            leadMinutes: 1,
            alreadyHandled: []
        )
        #expect(result.isEmpty)
    }

    @Test func speechIsQuietOnlyDuringAlertingEvents() {
        #expect(AlertPlanner.isInAlertingEvent(events: [Fixture.attended(standup)], now: Fixture.at(10, 15)))
        #expect(!AlertPlanner.isInAlertingEvent(events: [Fixture.attended(standup)], now: Fixture.at(10, 30)))
        let silenced = [Fixture.attended(standup, override: .silenced)]
        #expect(!AlertPlanner.isInAlertingEvent(events: silenced, now: Fixture.at(10, 15)))
    }
}

@Suite struct FullScreenLifecycleTests {
    private let standup = Fixture.event("Standup", from: Fixture.at(10))

    /// An alert left on screen must not outlive its event: it would also block the next event's alert.
    @Test func theAlertClosesWhenItsEventEnds() {
        let keep = AlertPlanner.keepsFullScreen(
            eventID: standup.id, events: [Fixture.attended(standup)], now: Fixture.at(10, 30), paused: false)
        #expect(!keep)
    }

    @Test func theAlertStaysWhileItsEventStillBlocks() {
        let keep = AlertPlanner.keepsFullScreen(
            eventID: standup.id, events: [Fixture.attended(standup)], now: Fixture.at(10, 5), paused: false)
        #expect(keep)
    }

    @Test func theAlertClosesWhenPausedOrNoLongerBlocking() {
        #expect(
            !AlertPlanner.keepsFullScreen(
                eventID: standup.id, events: [Fixture.attended(standup)], now: Fixture.at(9, 59), paused: true))
        #expect(
            !AlertPlanner.keepsFullScreen(
                eventID: standup.id, events: [Fixture.attended(standup, override: .noFullScreen)],
                now: Fixture.at(9, 59), paused: false))
    }
}

@Suite struct SharedRuleTests {
    private let standup = Fixture.event("Standup", from: Fixture.at(10))

    @Test(arguments: [(9, 58, 30, 2), (9, 59, 59, 1), (10, 0, 0, 0), (10, 5, 0, 0)])
    func minutesUntilStart(hour: Int, minute: Int, second: Int, expected: Int) {
        let now = Fixture.at(hour, minute).addingTimeInterval(Double(second))
        #expect(standup.minutesUntilStart(from: now) == expected)
    }

    @Test func allDayEventsComeFirst() {
        let holiday = Fixture.event("Holiday", from: Fixture.at(0), minutes: 24 * 60, allDay: true)
        let early = Fixture.event("Early", from: Fixture.at(8))
        #expect(
            [standup, holiday, early].sorted(by: CalendarEvent.displayOrder).map(\.title) == [
                "Holiday", "Early", "Standup",
            ])
    }

    @Test func deliveredKeepsATwoSecondMargin() {
        let now = Fixture.at(9, 55)
        let fireDates = [
            "fired": now.addingTimeInterval(-3), "firing": now.addingTimeInterval(-1),
            "later": now.addingTimeInterval(60),
        ]
        #expect(AlertPlanner.delivered(fireDates: fireDates, now: now) == ["fired"])
    }

    private func sayTime(
        _ now: Date, paused: Bool = false, away: Bool = false, last: Date? = nil, events: [AttendedEvent] = []
    ) -> Bool {
        AlertPlanner.shouldSayTime(
            now: now, interval: .halfHour, hours: SpeechHours(startHour: 8, endHour: 20), paused: paused, away: away,
            events: events, lastSpokenMinute: last, calendar: Fixture.calendar)
    }

    @Test func saysTheTimeOnlyWhenEveryConditionHolds() {
        #expect(sayTime(Fixture.at(10, 30)))
        #expect(!sayTime(Fixture.at(10, 15)))
        #expect(!sayTime(Fixture.at(21, 0)))
        #expect(!sayTime(Fixture.at(10, 30), paused: true))
        #expect(!sayTime(Fixture.at(10, 30), away: true))
        #expect(!sayTime(Fixture.at(10, 30), last: Fixture.at(10, 30)))
        #expect(!sayTime(Fixture.at(10, 0), events: [Fixture.attended(standup)]))
    }
}

/// Out of office and long events are listed, but they are not meetings.
@Suite struct BackgroundEventTests {
    private let conference = Fixture.event("Conference", from: Fixture.at(9), minutes: 8 * 60)
    private let away = Fixture.event("Out of office", from: Fixture.at(10), minutes: 60, availability: .unavailable)
    private let standup = Fixture.event("Standup", from: Fixture.at(10), minutes: 30)

    @Test func longAndOutOfOfficeEventsAreBackground() {
        #expect(conference.isBackground)
        #expect(away.isBackground)
        #expect(!standup.isBackground)
        #expect(!Fixture.event("Workshop", from: Fixture.at(9), minutes: 3 * 60).isBackground)
    }

    @Test func backgroundEventsSendNoReminder() {
        let reminders = AlertPlanner.reminders(
            events: [Fixture.attended(conference), Fixture.attended(away)], now: Fixture.at(8), leadMinutes: 5,
            delivered: [])
        #expect(reminders.isEmpty)
    }

    @Test func theVoiceSpeaksDuringALongEventButNotDuringAMeeting() {
        #expect(!AlertPlanner.isInAlertingEvent(events: [Fixture.attended(conference)], now: Fixture.at(11)))
        #expect(AlertPlanner.isInAlertingEvent(events: [Fixture.attended(standup)], now: Fixture.at(10, 10)))
    }

    @Test func theMenuBarIgnoresALongEvent() {
        let status = MenuBarStatus.resolve(
            events: [Fixture.attended(conference), Fixture.attended(standup)], now: Fixture.at(9, 15),
            countdownMinutes: 30)
        #expect(status == .freeUntil(Fixture.at(10)))
    }

    @Test func aRepeatingEventKeepsOneSeriesID() {
        let monday = Fixture.event("Standup", from: Fixture.at(10))
        let later = Fixture.event("Standup", from: Fixture.at(15))
        #expect(monday.seriesID == later.seriesID)
        #expect(monday.id != later.id)
    }
}
