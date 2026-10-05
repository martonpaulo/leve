import Foundation
import LeveKit
import Testing

@Suite struct MediaPauseTests {
    @Test func onlyRunningAppsAreAskedPlayersFirst() {
        let running: Set = ["com.apple.Safari", "com.apple.finder", "com.spotify.client"]
        #expect(MediaPause.targets(running: running) == [.spotify, .safari])
        #expect(MediaPause.targets(running: []).isEmpty)
    }

    @Test func everyScriptChecksTheAppRunsBeforeTellingIt() throws {
        for app in MediaApp.allCases {
            let script = MediaPause.script(for: app)
            let guardLine = try #require(script.range(of: "if application id \"\(app.bundleIdentifier)\" is running"))
            let tell = try #require(script.range(of: "tell application id \"\(app.bundleIdentifier)\""))
            #expect(guardLine.lowerBound < tell.lowerBound)
            #expect(!script.contains("launch"))
            #expect(!script.contains("activate"))
        }
    }

    @Test func aPlayerIsPausedOnlyWhenItPlays() {
        let script = MediaPause.script(for: .music)
        #expect(script.contains("if player state is playing then"))
        #expect(MediaPause.outcome(for: .music, reply: "paused", errorNumber: nil) == .paused(1))
        #expect(MediaPause.outcome(for: .spotify, reply: "idle", errorNumber: nil) == .notPlaying)
        #expect(MediaPause.outcome(for: .tv, reply: "what", errorNumber: nil) == .failed(0))
    }

    @Test func eachBrowserRunsThePageScriptInItsOwnWay() {
        #expect(MediaPause.script(for: .safari).contains("do JavaScript"))
        #expect(MediaPause.script(for: .chrome).contains("execute t javascript"))
        #expect(MediaPause.script(for: .brave).contains("execute t javascript"))
        // The page script sits inside an AppleScript string, so it must not hold a double quote.
        #expect(!MediaPause.pageScript.contains("\""))
        #expect(MediaPause.script(for: .chrome).contains(MediaPause.pageScript))
    }

    @Test func aBrowserReplyCountsThePausedElements() {
        #expect(MediaPause.outcome(for: .brave, reply: "2 5 1 -2700", errorNumber: nil) == .paused(2))
        #expect(MediaPause.outcome(for: .chrome, reply: "0 3 0 0", errorNumber: nil) == .notPlaying)
        #expect(MediaPause.outcome(for: .safari, reply: "0 0 0 0", errorNumber: nil) == .notPlaying)
        #expect(MediaPause.outcome(for: .safari, reply: "nonsense", errorNumber: nil) == .failed(0))
    }

    @Test func everyTabRefusingMeansJavaScriptIsOff() {
        #expect(MediaPause.outcome(for: .chrome, reply: "0 4 4 12", errorNumber: nil) == .javaScriptOff)
        #expect(MediaPause.outcome(for: .safari, reply: "0 2 2 -1728", errorNumber: nil) == .javaScriptOff)
        // One page that refuses, such as a browser settings page, is not the option being off.
        #expect(MediaPause.outcome(for: .chrome, reply: "0 4 1 12", errorNumber: nil) == .notPlaying)
        #expect(MediaPause.outcome(for: .brave, reply: "0 2 2 -1743", errorNumber: nil) == .notAllowed)
    }

    @Test func permissionAndErrorNumbersMapToOutcomes() {
        #expect(MediaPause.outcome(permissionStatus: 0) == nil)
        #expect(MediaPause.outcome(permissionStatus: -1743) == .notAllowed)
        #expect(MediaPause.outcome(permissionStatus: -1744) == .needsPermission)
        #expect(MediaPause.outcome(permissionStatus: -600) == .notRunning)
        #expect(MediaPause.outcome(permissionStatus: -50) == .failed(-50))
        #expect(MediaPause.outcome(for: .music, reply: nil, errorNumber: -1743) == .notAllowed)
        #expect(MediaPause.outcome(for: .safari, reply: nil, errorNumber: -609) == .notRunning)
        #expect(MediaPause.outcome(for: .spotify, reply: nil, errorNumber: -1712) == .failed(-1712))
    }

    @Test func theHintKeepsABrowserUntilItAnswers() {
        let refused = MediaPause.javaScriptOff(previous: [], outcomes: [.brave: .javaScriptOff, .music: .paused(1)])
        #expect(refused == [.brave])
        // Brave was not running at the next break: the hint stays.
        #expect(MediaPause.javaScriptOff(previous: refused, outcomes: [.safari: .notPlaying]) == [.brave])
        #expect(MediaPause.javaScriptOff(previous: refused, outcomes: [.brave: .notPlaying]).isEmpty)
        #expect(MediaPause.javaScriptOff(previous: refused, outcomes: [.brave: .paused(1)]).isEmpty)
    }

    @Test func permissionIsAskedAfterTheBreakOnlyWhereItIsMissing() {
        let outcomes: [MediaApp: MediaPauseOutcome] = [
            .spotify: .needsPermission, .safari: .notAllowed, .tv: .notPlaying,
        ]
        #expect(MediaPause.needingPermission(outcomes) == [.spotify])
    }

    @Test func nothingIsAskedOnceTheSettingIsTurnedOffDuringTheBreak() {
        #expect(MediaPause.permissionToAsk(pending: [.spotify, .safari], settingIsOn: true) == [.spotify, .safari])
        #expect(MediaPause.permissionToAsk(pending: [.spotify, .safari], settingIsOn: false).isEmpty)
    }

    @Test func theLogLineNamesAppsAndOutcomesOnly() {
        #expect(MediaPause.logLine([:]) == "no player running")
        #expect(
            MediaPause.logLine([.safari: .javaScriptOff, .music: .paused(1)])
                == "music paused 1, safari JavaScript from Apple Events off")
    }
}
