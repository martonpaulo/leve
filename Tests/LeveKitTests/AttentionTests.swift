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
