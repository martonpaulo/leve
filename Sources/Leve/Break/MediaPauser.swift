import AppKit
import CoreServices
import LeveKit

/// Pauses what plays in Music, Spotify, TV and the browsers' tabs when a break starts, with Apple
/// Events (#2). `MediaPause` decides what to send and what each answer means; this only sends.
/// Nothing is resumed, and an app that is not running is never launched.
enum MediaPauser {
    /// One app at a time, off the main thread: an Apple Event waits for its reply, and asking for
    /// permission waits for the user (AE/AppleEvents.h, AEDeterminePermissionToAutomateTarget).
    private static let queue = DispatchQueue(label: "com.martonpaulo.leve.media", qos: .userInitiated)

    static var runningTargets: [MediaApp] {
        MediaPause.targets(running: Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)))
    }

    /// Pauses every running target, without asking for permission: the macOS prompt could open
    /// under the break, so an app that still needs it answers `needsPermission`.
    static func pauseAll() async -> [MediaApp: MediaPauseOutcome] {
        await run(runningTargets) { app in
            if let outcome = MediaPause.outcome(permissionStatus: permission(app, ask: false)) {
                return outcome
            }
            return pause(app)
        }
    }

    /// Lets macOS ask the user, once per app, whether Leve may control it.
    static func askPermission(for apps: [MediaApp]) async -> [MediaApp: MediaPauseOutcome] {
        await run(apps) { app in
            MediaPause.outcome(permissionStatus: permission(app, ask: true)) ?? .allowed
        }
    }

    private static func run(
        _ apps: [MediaApp], _ body: @escaping @Sendable (MediaApp) -> MediaPauseOutcome
    ) async -> [MediaApp: MediaPauseOutcome] {
        guard !apps.isEmpty else { return [:] }
        return await withCheckedContinuation { continuation in
            queue.async {
                var outcomes: [MediaApp: MediaPauseOutcome] = [:]
                for app in apps {
                    outcomes[app] = body(app)
                }
                continuation.resume(returning: outcomes)
            }
        }
    }

    /// `noErr`, `errAEEventNotPermitted`, `errAEEventWouldRequireUserConsent` or `procNotFound`.
    nonisolated private static func permission(_ app: MediaApp, ask: Bool) -> Int {
        let target = NSAppleEventDescriptor(bundleIdentifier: app.bundleIdentifier)
        return Int(AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, ask))
    }

    nonisolated private static func pause(_ app: MediaApp) -> MediaPauseOutcome {
        guard let script = NSAppleScript(source: MediaPause.script(for: app)) else { return .failed(0) }
        var error: NSDictionary?
        let reply = script.executeAndReturnError(&error)
        if let error {
            return MediaPause.outcome(
                for: app, reply: nil, errorNumber: error[NSAppleScript.errorNumber] as? Int ?? 0)
        }
        return MediaPause.outcome(for: app, reply: reply.stringValue, errorNumber: nil)
    }
}
