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

    @Test func thePauseButtonStillAsksForPermissionWithTheSettingOff() {
        #expect(
            MediaPause.permissionToAsk(pending: [.brave], settingIsOn: false, pausedOnRequest: true) == [.brave])
    }

    @Test func theLogLineNamesAppsAndOutcomesOnly() {
        #expect(MediaPause.logLine([:]) == "no player running")
        #expect(
            MediaPause.logLine([.safari: .javaScriptOff, .music: .paused(1)])
                == "music paused 1, safari JavaScript from Apple Events off")
    }
}

@Suite struct MediaFixTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func aRefusalIsAProblemAndIsNotifiedOnce() {
        var fix = MediaFix()
        #expect(fix.record([.brave: .javaScriptOff, .music: .paused(1)], now: start) == [.brave])
        #expect(fix.problems == [.brave: .javaScriptOff])
        // The same unchanged problem at the next breaks: no notification, the fix stays in Settings.
        #expect(fix.record([.brave: .javaScriptOff], now: start.addingTimeInterval(3600)).isEmpty)
        #expect(fix.record([.brave: .javaScriptOff], now: start.addingTimeInterval(86_400)).isEmpty)
        #expect(fix.apps == [.brave])
    }

    @Test func everyAppPausedOrNothingAskedPostsNothing() {
        var fix = MediaFix()
        #expect(fix.record([:], now: start).isEmpty)
        #expect(fix.record([.music: .paused(1), .safari: .notPlaying, .tv: .notRunning], now: start).isEmpty)
        #expect(fix.problems.isEmpty)
    }

    @Test func aNewProblemIsNotifiedAndNamesOnlyWhatThisBreakFound() {
        var fix = MediaFix()
        _ = fix.record([.brave: .javaScriptOff], now: start)
        // Brave is not running at this break; Music refuses for the first time.
        #expect(fix.record([.music: .notAllowed], now: start.addingTimeInterval(60)) == [.music])
        #expect(fix.apps == [.music, .brave])
    }

    @Test func anAppThatWasNotAskedKeepsItsProblem() {
        var fix = MediaFix()
        _ = fix.record([.safari: .javaScriptOff], now: start)
        _ = fix.record([.brave: .notPlaying, .spotify: .needsPermission, .tv: .failed(-1712)], now: start)
        #expect(fix.problems == [.safari: .javaScriptOff])
    }

    @Test func aFixedProblemThatComesBackIsNotifiedAgain() {
        var fix = MediaFix()
        _ = fix.record([.brave: .javaScriptOff], now: start)
        #expect(fix.record([.brave: .paused(2)], now: start.addingTimeInterval(60)).isEmpty)
        #expect(fix.problems.isEmpty)
        #expect(fix.record([.brave: .javaScriptOff], now: start.addingTimeInterval(120)) == [.brave])
    }

    @Test func aDifferentProblemForTheSameAppIsNotified() {
        var fix = MediaFix()
        _ = fix.record([.brave: .javaScriptOff], now: start)
        #expect(fix.record([.brave: .notAllowed], now: start.addingTimeInterval(60)) == [.brave])
    }

    @Test func anUnchangedProblemIsNotifiedAgainAfterAWeek() {
        var fix = MediaFix()
        _ = fix.record([.brave: .javaScriptOff], now: start)
        let almost = start.addingTimeInterval(MediaFix.repeatAfter - 1)
        #expect(fix.record([.brave: .javaScriptOff], now: almost).isEmpty)
        let week = start.addingTimeInterval(MediaFix.repeatAfter)
        #expect(fix.record([.brave: .javaScriptOff], now: week) == [.brave])
        #expect(fix.record([.brave: .javaScriptOff], now: week.addingTimeInterval(60)).isEmpty)
    }

    @Test func anAllowedAppOrTheSettingTurnedOffClearsTheFix() {
        var fix = MediaFix()
        _ = fix.record([.music: .notAllowed, .safari: .javaScriptOff], now: start)
        fix.forgetAllowed([.music: .allowed, .safari: .allowed])
        // Permission does not turn on a browser's JavaScript option.
        #expect(fix.apps == [.safari])
        _ = fix.record([.safari: .allowed], now: start)
        #expect(fix.apps == [.safari])
        fix.clear()
        #expect(fix.problems.isEmpty)
        #expect(fix.record([.safari: .javaScriptOff], now: start.addingTimeInterval(60)) == [.safari])
    }
}

@Suite struct PauseButtonTests {
    @Test func onlyAnotherProcessPlayingCountsAsSound() {
        let own: Int32 = 42
        #expect(!MediaPause.isOtherAudioPlaying([], ownPID: own))
        // The break's own tone plays in Leve's process.
        #expect(!MediaPause.isOtherAudioPlaying([AudioProcess(pid: own, isRunningOutput: true)], ownPID: own))
        #expect(!MediaPause.isOtherAudioPlaying([AudioProcess(pid: 7, isRunningOutput: false)], ownPID: own))
        #expect(
            MediaPause.isOtherAudioPlaying(
                [AudioProcess(pid: own, isRunningOutput: true), AudioProcess(pid: 7, isRunningOutput: true)],
                ownPID: own))
    }

    @Test func theButtonShowsOnlyWithTheSettingOffAndSoundPlaying() {
        #expect(MediaPause.offersPauseButton(settingIsOn: false, otherAudioPlaying: true))
        #expect(!MediaPause.offersPauseButton(settingIsOn: true, otherAudioPlaying: true))
        #expect(!MediaPause.offersPauseButton(settingIsOn: false, otherAudioPlaying: false))
        #expect(!MediaPause.offersPauseButton(settingIsOn: true, otherAudioPlaying: false))
    }
}
