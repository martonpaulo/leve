import Testing

@testable import Leve

/// The updater starts only in a bundled Leve.app; the test runner is not one, like `make run`.
@MainActor @Suite struct UpdateManagerTests {
    @Test func anUnbundledBuildHasNoUpdater() {
        let updates = UpdateManager()
        updates.startIfBundled()
        #expect(!updates.isAvailable)
        #expect(!updates.canCheckForUpdates)
        #expect(updates.lastCheckDate == nil)
        // Without an updater, a check is a no-op rather than a crash.
        updates.checkForUpdates()
    }
}
