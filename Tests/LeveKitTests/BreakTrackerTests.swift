import Foundation
import LeveKit
import Testing

@Suite struct BreakTrackerTests {
    private let schedule = BreakSchedule(workMinutes: 55, breakMinutes: 5)

    private func context(idle: Double = 0, busy: Bool = false, soon: Bool = false, paused: Bool = false)
        -> BreakContext
    {
        BreakContext(idleSeconds: idle, isBusy: busy, eventStartsSoon: soon, isPaused: paused)
    }

    /// `#expect` cannot call a mutating method, so the tick goes through this helper.
    private func due(_ tracker: inout BreakTracker, now: Date, context: BreakContext) -> Bool {
        tracker.isDue(now: now, context: context, schedule: schedule)
    }

    @Test func dueAfterTheWorkTime() {
        var tracker = BreakTracker(now: Fixture.at(9))
        #expect(!due(&tracker, now: Fixture.at(9, 54), context: context()))
        #expect(due(&tracker, now: Fixture.at(9, 55), context: context()))
    }

    @Test func timeAwayAsLongAsABreakCountsAsOne() {
        var tracker = BreakTracker(now: Fixture.at(9))
        #expect(!due(&tracker, now: Fixture.at(9, 40), context: context(idle: 5 * 60)))
        #expect(tracker.workStart == Fixture.at(9, 40))
        #expect(!due(&tracker, now: Fixture.at(10, 0), context: context()))
    }

    @Test func aMeetingCountsAndTheBreakFollowsIt() {
        var tracker = BreakTracker(now: Fixture.at(9))
        // Listening in a call is idle at the keyboard, but it is not a break. Ticks come every minute.
        for minute in 58...89 {
            #expect(!due(&tracker, now: Fixture.at(9, minute), context: context(idle: 20 * 60, busy: true)))
        }
        #expect(tracker.workStart == Fixture.at(9))
        #expect(due(&tracker, now: Fixture.at(10, 30), context: context()))
    }

    @Test func waitsForAnEventThatStartsSoonAndForThePause() {
        var tracker = BreakTracker(now: Fixture.at(9))
        #expect(!due(&tracker, now: Fixture.at(10), context: context(soon: true)))
        #expect(!due(&tracker, now: Fixture.at(10), context: context(paused: true)))
    }

    @Test func laterAsksAgainAndRestartResets() {
        var tracker = BreakTracker(now: Fixture.at(9))
        tracker.postpone(now: Fixture.at(10), minutes: 5)
        #expect(!due(&tracker, now: Fixture.at(10, 4), context: context()))
        #expect(due(&tracker, now: Fixture.at(10, 5), context: context()))
        tracker.restart(now: Fixture.at(10, 10))
        #expect(!due(&tracker, now: Fixture.at(10, 20), context: context()))
    }

    /// A Mac asleep overnight sends no ticks; the gap is a break, not 8 hours of work.
    @Test func aLongGapBetweenTicksCountsAsABreak() {
        var tracker = BreakTracker(now: Fixture.at(9))
        #expect(!due(&tracker, now: Fixture.at(9, 30), context: context()))
        #expect(!due(&tracker, now: Fixture.at(17, 30), context: context()))
        #expect(tracker.workStart == Fixture.at(17, 30))
    }

    @Test func onlyAlertingTimedEventsStartSoon() {
        let standup = Fixture.event("Standup", from: Fixture.at(10, 3))
        let now = Fixture.at(10)
        #expect(BreakTracker.eventStartsSoon(events: [Fixture.attended(standup)], now: now, minutes: 5))
        #expect(
            !BreakTracker.eventStartsSoon(
                events: [Fixture.attended(standup, override: .silenced)], now: now, minutes: 5))
        #expect(!BreakTracker.eventStartsSoon(events: [Fixture.attended(standup)], now: now, minutes: 2))
    }
}
