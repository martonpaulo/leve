import LeveKit
import Testing

@Suite struct AttentionTests {
    @Test func everythingAlertsAndBlocks() {
        let attention = EventAttention.resolve(rule: .everything, override: nil)
        #expect(attention.isListed && attention.isAlerting && attention.blocksScreen)
    }

    @Test func noFullScreenAlertsWithoutBlocking() {
        let attention = EventAttention.resolve(rule: .noFullScreen, override: nil)
        #expect(attention.isAlerting && !attention.blocksScreen)
    }

    @Test func menuOnlyIsListedButQuiet() {
        let attention = EventAttention.resolve(rule: .menuOnly, override: nil)
        #expect(attention.isListed && !attention.isAlerting && !attention.blocksScreen)
    }

    @Test func ignoreHidesEverything() {
        let attention = EventAttention.resolve(rule: .ignore, override: nil)
        #expect(!attention.isListed && !attention.isAlerting)
    }

    @Test func silencedStaysListedWithoutAlerts() {
        let attention = EventAttention.resolve(rule: .everything, override: .silenced)
        #expect(attention.isListed && !attention.isAlerting && !attention.blocksScreen)
    }

    @Test func hiddenWinsOverTheRule() {
        let attention = EventAttention.resolve(rule: .everything, override: .hidden)
        #expect(!attention.isListed && !attention.isAlerting)
    }

    @Test func noFullScreenOverrideKeepsTheNotification() {
        let attention = EventAttention.resolve(rule: .everything, override: .noFullScreen)
        #expect(attention.isAlerting && !attention.blocksScreen)
    }

    @Test func overrideNeverRaisesAnIgnoredCalendar() {
        let attention = EventAttention.resolve(rule: .ignore, override: .noFullScreen)
        #expect(!attention.isListed && !attention.isAlerting)
    }
}

@Suite struct ChoiceKeyTests {
    /// A choice made for an event must survive the organizer moving it to another time that day.
    @Test func aMovedEventKeepsItsChoiceKey() {
        let before = Fixture.event("Standup", from: Fixture.at(10))
        let after = Fixture.event("Standup", from: Fixture.at(10, 15))
        #expect(before.choiceKey(calendar: Fixture.calendar) == after.choiceKey(calendar: Fixture.calendar))
    }

    @Test func anotherDayIsAnotherChoice() {
        let today = Fixture.event("Standup", from: Fixture.at(10))
        let tomorrow = Fixture.event("Standup", from: Fixture.at(10).addingTimeInterval(24 * 60 * 60))
        #expect(today.choiceKey(calendar: Fixture.calendar) != tomorrow.choiceKey(calendar: Fixture.calendar))
    }

    @Test func anOldOccurrenceIDMigratesToItsChoiceKey() {
        let event = Fixture.event("Standup", from: Fixture.at(10))
        let migrated = CalendarEvent.choiceKey(fromOccurrenceID: event.id, calendar: Fixture.calendar)
        #expect(migrated == event.choiceKey(calendar: Fixture.calendar))
    }
}
