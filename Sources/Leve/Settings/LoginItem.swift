import Foundation
import OSLog
import Observation
import ServiceManagement

/// Launch at login through `SMAppService.mainApp`, off by default, showing every status
/// (skd-macos-app-shell, settings-architecture.md).
@Observable
final class LoginItem {
    enum State: Equatable {
        case on
        case off
        case needsApproval
        case unavailable
    }

    private(set) var state: State = .off
    private(set) var failed = false
    @ObservationIgnored private let logger = Logger(subsystem: "com.martonpaulo.leve", category: "login")

    /// A `swift build` binary is not a bundle; registering it would schedule that executable.
    private var isRealBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    /// Reads only; never registers.
    func refresh() {
        guard isRealBundle else {
            state = .unavailable
            return
        }
        switch SMAppService.mainApp.status {
        case .enabled: state = .on
        case .requiresApproval: state = .needsApproval
        case .notRegistered, .notFound: state = .off
        @unknown default: state = .off
        }
    }

    func set(_ enabled: Bool) {
        guard isRealBundle else { return }
        failed = false
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Login item change failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
        let reached = enabled ? (state == .on || state == .needsApproval) : state == .off
        failed = !reached
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
