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
}
