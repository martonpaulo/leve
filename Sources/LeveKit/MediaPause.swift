import Foundation

/// An app whose playback Leve pauses when a break starts (#2).
public enum MediaApp: String, CaseIterable, Sendable {
    case music, spotify, tv, brave, chrome, safari

    public var bundleIdentifier: String {
        switch self {
        case .music: "com.apple.Music"
        case .spotify: "com.spotify.client"
        case .tv: "com.apple.TV"
        case .brave: "com.brave.Browser"
        case .chrome: "com.google.Chrome"
        case .safari: "com.apple.Safari"
        }
    }

    /// A browser pauses the media elements of its tabs; the other apps have a player to pause.
    public var isBrowser: Bool {
        switch self {
        case .music, .spotify, .tv: false
        case .brave, .chrome, .safari: true
        }
    }
}

/// What asking one app to pause gave.
public enum MediaPauseOutcome: Equatable, Sendable {
    /// The player, or this many media elements in the browser's tabs, were paused.
    case paused(Int)
    case notPlaying
    /// The app quit before it was asked; it is never launched to ask it.
    case notRunning
    /// macOS has not asked the user yet whether Leve may control this app.
    case needsPermission
    /// The user did not allow Leve to control this app.
    case notAllowed
    /// The browser refused to run JavaScript from Apple Events in every tab.
    case javaScriptOff
    case failed(Int)
    /// The permission check passed; nothing was asked to pause.
    case allowed

    /// A stable word for the log, with no personal data.
    public var logDescription: String {
        switch self {
        case .paused(let count): "paused \(count)"
        case .notPlaying: "not playing"
        case .notRunning: "not running"
        case .needsPermission: "needs permission"
        case .notAllowed: "not allowed"
        case .javaScriptOff: "JavaScript from Apple Events off"
        case .failed(let code): "failed \(code)"
        case .allowed: "allowed"
        }
    }
}

/// One process Core Audio knows, and whether it plays sound now (#13).
public struct AudioProcess: Equatable, Sendable {
    public let pid: Int32
    public let isRunningOutput: Bool

    public init(pid: Int32, isRunningOutput: Bool) {
        self.pid = pid
        self.isRunningOutput = isRunningOutput
    }
}

/// Why an app kept playing after Leve asked it to pause, and the user can fix (#12).
public enum MediaProblem: Equatable, Sendable {
    /// The browser refused to run JavaScript from Apple Events in every tab.
    case javaScriptOff
    /// The user did not allow Leve to control the app.
    case notAllowed
}

/// The media problems Leve knows of, for the fix in Settings, Breaks, and when to post the
/// notification after a break (#12). A notification is posted when a break finds a problem and
/// the known problems differ from the ones last notified, or `repeatAfter` has passed since.
public struct MediaFix: Equatable, Sendable {
    public static let repeatAfter: TimeInterval = 7 * 24 * 60 * 60

    public private(set) var problems: [MediaApp: MediaProblem] = [:]
    private var notified: [MediaApp: MediaProblem] = [:]
    private var notifiedAt: Date?

    public init() {}

    /// The apps with a problem, in a fixed order.
    public var apps: [MediaApp] { MediaApp.allCases.filter { problems[$0] != nil } }

    /// Takes a break's answers and returns the apps to name in a notification, or none. An app that
    /// was not asked, or did not answer, keeps its state.
    public mutating func record(_ outcomes: [MediaApp: MediaPauseOutcome], now: Date) -> [MediaApp] {
        var found: [MediaApp] = []
        for app in MediaApp.allCases {
            switch outcomes[app] {
            case .javaScriptOff:
                problems[app] = .javaScriptOff
                found.append(app)
            case .notAllowed:
                problems[app] = .notAllowed
                found.append(app)
            case .paused, .notPlaying:
                problems[app] = nil
            case .allowed:
                // Permission says nothing about a browser's JavaScript option.
                if problems[app] == .notAllowed { problems[app] = nil }
            case .notRunning, .needsPermission, .failed, nil:
                break
            }
        }
        // A fixed problem leaves the notified set, so it is posted again if it comes back.
        notified = notified.filter { problems[$0.key] == $0.value }
        guard !found.isEmpty else { return [] }
        let changed = problems != notified
        let due = notifiedAt.map { now.timeIntervalSince($0) >= Self.repeatAfter } ?? true
        guard changed || due else { return [] }
        notified = problems
        notifiedAt = now
        return found
    }

    /// Drops the apps the user has since allowed in System Settings, from a permission check.
    public mutating func forgetAllowed(_ outcomes: [MediaApp: MediaPauseOutcome]) {
        for (app, outcome) in outcomes where outcome == .allowed && problems[app] == .notAllowed {
            problems[app] = nil
            notified[app] = nil
        }
    }

    /// Forgets every problem, when the setting is turned off.
    public mutating func clear() {
        self = MediaFix()
    }
}

/// Which apps to ask, what to send them, and what their answers mean. The app target only sends
/// the Apple Events; it never launches an app that is not running.
public enum MediaPause {
    /// `errAEEventNotPermitted`, `errAEEventWouldRequireUserConsent`, `procNotFound` and
    /// `connectionInvalid` (AE/AppleEvents.h, CarbonCore/MacErrors.h).
    public static let notPermitted = -1743
    public static let wouldRequireConsent = -1744
    public static let processNotFound = -600
    public static let connectionInvalid = -609

    /// The running apps to ask, players first, in a fixed order.
    public static func targets(running bundleIdentifiers: Set<String>) -> [MediaApp] {
        MediaApp.allCases.filter { bundleIdentifiers.contains($0.bundleIdentifier) }
    }

    /// The outcome of the permission check made before the script, or nil when the script may run.
    public static func outcome(permissionStatus status: Int) -> MediaPauseOutcome? {
        switch status {
        case 0: nil
        case notPermitted: .notAllowed
        case wouldRequireConsent: .needsPermission
        case processNotFound, connectionInvalid: .notRunning
        default: .failed(status)
        }
    }

    /// The outcome of the script, from its text reply or the number of the error it raised.
    public static func outcome(for app: MediaApp, reply: String?, errorNumber: Int?) -> MediaPauseOutcome {
        if let errorNumber {
            return outcome(permissionStatus: errorNumber) ?? .failed(errorNumber)
        }
        guard let reply else { return .failed(0) }
        if !app.isBrowser {
            switch reply {
            case "paused": return .paused(1)
            case "idle": return .notPlaying
            default: return .failed(0)
            }
        }
        let numbers = reply.split(separator: " ").compactMap { Int($0) }
        guard numbers.count == 4 else { return .failed(0) }
        let (paused, tried, failed, lastError) = (numbers[0], numbers[1], numbers[2], numbers[3])
        if paused > 0 { return .paused(paused) }
        // A browser with the option off refuses every tab; one odd page alone does not count.
        if tried > 0, failed == tried {
            return lastError == notPermitted ? .notAllowed : .javaScriptOff
        }
        return .notPlaying
    }

    /// The apps for which macOS should ask the user once the break is over.
    public static func needingPermission(_ outcomes: [MediaApp: MediaPauseOutcome]) -> [MediaApp] {
        MediaApp.allCases.filter { outcomes[$0] == .needsPermission }
    }

    /// What to ask for when the break ends: nothing once the setting was turned off meanwhile,
    /// unless the pause was asked for from the break screen (#13).
    public static func permissionToAsk(pending: [MediaApp], settingIsOn: Bool, pausedOnRequest: Bool = false)
        -> [MediaApp]
    {
        settingIsOn || pausedOnRequest ? pending : []
    }

    /// Whether a process other than Leve plays sound: Leve's own tones never count (#13).
    public static func isOtherAudioPlaying(_ processes: [AudioProcess], ownPID: Int32) -> Bool {
        processes.contains { $0.isRunningOutput && $0.pid != ownPID }
    }

    /// The break screen offers "Pause Music and Videos" only when Leve would not pause on its own
    /// and something plays (#13).
    public static func offersPauseButton(settingIsOn: Bool, otherAudioPlaying: Bool) -> Bool {
        !settingIsOn && otherAudioPlaying
    }

    /// One log line for a break: each app asked and its outcome.
    public static func logLine(_ outcomes: [MediaApp: MediaPauseOutcome]) -> String {
        let parts = MediaApp.allCases.compactMap { app in
            outcomes[app].map { "\(app.rawValue) \($0.logDescription)" }
        }
        return parts.isEmpty ? "no player running" : parts.joined(separator: ", ")
    }

    /// Pauses every `<video>` and `<audio>` that plays in the page, and returns how many.
    public static let pageScript =
        "(function(){var n=0;document.querySelectorAll('video,audio').forEach(function(m){"
        + "if(!m.paused){m.pause();n++;}});return String(n);})()"

    /// The AppleScript for one app. It starts by checking that the app runs, because `tell` would
    /// launch an app that quit meanwhile. A player replies "paused" or "idle"; a browser replies
    /// "<paused> <tabs tried> <tabs failed> <last error number>".
    public static func script(for app: MediaApp) -> String {
        let id = app.bundleIdentifier
        guard app.isBrowser else {
            return """
                if application id "\(id)" is running then
                    with timeout of 5 seconds
                        tell application id "\(id)"
                            if player state is playing then
                                pause
                                return "paused"
                            end if
                        end tell
                    end timeout
                end if
                return "idle"
                """
        }
        let run =
            app == .safari
            ? "do JavaScript \"\(pageScript)\" in t"
            : "execute t javascript \"\(pageScript)\""
        return """
            set pausedCount to 0
            set triedCount to 0
            set failedCount to 0
            set lastError to 0
            if application id "\(id)" is running then
                with timeout of 5 seconds
                    tell application id "\(id)"
                        repeat with w in windows
                            try
                                set pageTabs to tabs of w
                            on error
                                set pageTabs to {}
                            end try
                            repeat with t in pageTabs
                                set triedCount to triedCount + 1
                                try
                                    set answer to \(run)
                                    try
                                        set pausedCount to pausedCount + (answer as integer)
                                    end try
                                on error number errorNumber
                                    set failedCount to failedCount + 1
                                    set lastError to errorNumber
                                end try
                            end repeat
                        end repeat
                    end tell
                end timeout
            end if
            return (pausedCount as text) & " " & (triedCount as text) & " " & (failedCount as text) & " " & (lastError as text)
            """
    }
}
