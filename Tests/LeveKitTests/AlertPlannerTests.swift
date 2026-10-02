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
