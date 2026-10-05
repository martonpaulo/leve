import LeveKit
import Testing

@Suite struct MenuBarStatusTests {
    private let standup = Fixture.event("Standup", from: Fixture.at(10))
    private let review = Fixture.event("Review", from: Fixture.at(14), minutes: 60)

    @Test func freeUntilTheNextEventWhenItIsFarAway() {
        let status = MenuBarStatus.resolve(
            events: [Fixture.attended(standup)], now: Fixture.at(8), countdownMinutes: 30)
        #expect(status == .freeUntil(Fixture.at(10)))
    }

    @Test func countsDownInsideTheWindow() {
        let status = MenuBarStatus.resolve(
            events: [Fixture.attended(standup)], now: Fixture.at(9, 48), countdownMinutes: 30)
        #expect(status == .upcoming(title: "Standup", minutes: 12))
    }

    @Test func roundsUpSoTheLastMinuteNeverReadsZero() {
        let status = MenuBarStatus.resolve(
            events: [Fixture.attended(standup)], now: Fixture.at(9, 59).addingTimeInterval(30), countdownMinutes: 30)
        #expect(status == .upcoming(title: "Standup", minutes: 1))
    }

    @Test func showsTimeLeftDuringAnEvent() {
        let status = MenuBarStatus.resolve(
            events: [Fixture.attended(standup), Fixture.attended(review)], now: Fixture.at(10, 10), countdownMinutes: 30
        )
        #expect(status == .ongoing(title: "Standup", minutesLeft: 20, end: Fixture.at(10, 30)))
    }

    @Test func clearWhenNothingIsLeft() {
        let status = MenuBarStatus.resolve(
            events: [Fixture.attended(standup)], now: Fixture.at(18), countdownMinutes: 30)
        #expect(status == .clear)
    }

    @Test func silencedAndAllDayEventsDoNotCount() {
        let holiday = Fixture.event("Holiday", from: Fixture.at(0), minutes: 24 * 60, allDay: true)
        let events = [
            Fixture.attended(holiday),
            Fixture.attended(standup, override: .silenced),
            Fixture.attended(review),
        ]
        let status = MenuBarStatus.resolve(events: events, now: Fixture.at(9, 50), countdownMinutes: 30)
        #expect(status == .freeUntil(Fixture.at(14)))
    }

    @Test func freeUntilShowsTextOnlyWhenKept() {
        let free = MenuBarStatus.freeUntil(Fixture.at(14))
        #expect(free.showsText(freeUntil: true))
        #expect(!free.showsText(freeUntil: false))
    }

    @Test func nothingElseTodayNeverShowsTextAndEventsAlwaysDo() {
        for kept in [true, false] {
            #expect(!MenuBarStatus.clear.showsText(freeUntil: kept))
            #expect(MenuBarStatus.upcoming(title: "Standup", minutes: 12).showsText(freeUntil: kept))
            #expect(
                MenuBarStatus.ongoing(title: "Standup", minutesLeft: 20, end: Fixture.at(10, 30))
                    .showsText(freeUntil: kept))
        }
    }
}
