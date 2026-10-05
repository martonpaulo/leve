import Foundation
import OSLog
import Observation
import Sparkle

/// Sparkle 2's standard updater (#7, skd-macos-app-shell "Updates with Sparkle"). Update checks are
/// Leve's only network activity: Sparkle reads the appcast on GitHub and sends nothing about the
/// Mac or its calendars. Sparkle's own windows offer, download and install an update. The updater
/// starts only in a bundled Leve.app that names a feed, so `make run` has none and hides its
/// commands.
@Observable
final class UpdateManager: NSObject, SPUUpdaterDelegate {
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
    @ObservationIgnored private let logger = Logger(subsystem: "com.martonpaulo.leve", category: "updates")

    /// Whether the updater runs: false in an unbundled build.
    private(set) var isAvailable = false
    /// False while a check or an update session is already in progress (Sparkle's own state).
    private(set) var canCheckForUpdates = false
    /// When Sparkle last checked, scheduled or by hand; nil before the first check.
    private(set) var lastCheckDate: Date?
    /// Sparkle's own setting, which it keeps in Leve's user defaults; this only mirrors it so the
    /// toggle redraws. `SUEnableAutomaticChecks` in Info.plist sets the first value.
    var automaticallyChecks = true {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }

    func startIfBundled() {
        guard controller == nil, Bundle.main.bundleURL.pathExtension == "app",
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        isAvailable = true
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        lastCheckDate = controller.updater.lastUpdateCheckDate
        // Sparkle documents canCheckForUpdates as KVO-observable; it changes on the main thread.
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) {
            [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    // MARK: SPUUpdaterDelegate (called on the main thread, per Sparkle 2)

    func updater(
        _ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?
    ) {
        lastCheckDate = updater.lastUpdateCheckDate
        if let error {
            logger.notice("Update cycle ended: \((error as NSError).localizedDescription, privacy: .public)")
        }
    }
}
