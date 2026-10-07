import LeveKit
import Testing

@Suite struct OverlayDisplayTests {
    @Test func theContentStaysOnItsDisplayWhileItIsConnected() {
        #expect(OverlayDisplay.content(connected: [1, 2], previous: 2, pointer: 1) == 2)
    }

    @Test func aRemovedDisplayHandsTheContentToThePointersDisplay() {
        #expect(OverlayDisplay.content(connected: [1, 3], previous: 2, pointer: 3) == 3)
    }

    @Test func withoutThePointerTheFirstDisplayTakesIt() {
        #expect(OverlayDisplay.content(connected: [4, 5], previous: 2, pointer: nil) == 4)
        #expect(OverlayDisplay.content(connected: [], previous: 2, pointer: 1) == nil)
    }

    /// The screen takes seconds, not a blink, and the sound never rises faster than it (#21).
    @Test func theFullScreenComesInGently() {
        let entrance = OverlayDisplay.entrance(reduceMotion: false)
        #expect(entrance.fade >= 2)
        #expect(entrance.soundRise >= entrance.fade)
        let still = OverlayDisplay.entrance(reduceMotion: true)
        #expect(still.fade == 0)
        #expect(still.soundRise == entrance.soundRise)
    }
}
