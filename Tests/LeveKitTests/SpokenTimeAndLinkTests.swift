import Foundation
import LeveKit
import Testing

@Suite struct SpokenTimeTests {
    @Test(arguments: [(10, 0, "It's 10 AM"), (10, 30, "It's 10:30 AM"), (13, 15, "It's 1:15 PM"), (0, 0, "It's 12 AM")])
    func englishPhrase(hour: Int, minute: Int, expected: String) {
        let phrase = SpokenTime.phrase(for: Fixture.at(hour, minute), calendar: Fixture.calendar)
        // The formatter puts a narrow no-break space before AM and PM.
        #expect(phrase.replacingOccurrences(of: "\u{202F}", with: " ") == expected)
    }

    @Test func halfHourBoundaries() {
        #expect(SpeechInterval.halfHour.isBoundary(Fixture.at(10, 30), calendar: Fixture.calendar))
        #expect(!SpeechInterval.halfHour.isBoundary(Fixture.at(10, 15), calendar: Fixture.calendar))
        #expect(!SpeechInterval.off.isBoundary(Fixture.at(10, 0), calendar: Fixture.calendar))
    }
}

@Suite struct MeetingLinkTests {
    @Test func theEventURLWins() throws {
        let url = try #require(URL(string: "https://zoom.us/j/1"))
        let link = MeetingLink.resolve(url: url, location: nil, notes: "https://meet.google.com/abc-defg-hij")
        #expect(link == MeetingLink(url: url, provider: .zoom))
    }

    @Test func aKnownCallLinkInNotesBeatsOtherLinks() {
        let notes = "Agenda: https://docs.example.com/a\nJoin: https://meet.google.com/abc-defg-hij"
        let link = MeetingLink.resolve(url: nil, location: nil, notes: notes)
        #expect(link?.provider == .googleMeet)
        #expect(link?.url.absoluteString == "https://meet.google.com/abc-defg-hij")
    }

    @Test func theLocationIsSearchedToo() {
        let link = MeetingLink.resolve(url: nil, location: "https://teams.microsoft.com/l/meetup-join/x", notes: nil)
        #expect(link?.provider == .microsoftTeams)
    }

    @Test func noLinkWhenThereIsNone() {
        #expect(MeetingLink.resolve(url: nil, location: "Room 4", notes: "Bring coffee") == nil)
    }
}

@Suite struct SpokenAlertTests {
    private let standup = Fixture.event("Standup", from: Fixture.at(10))

    @Test(arguments: [(2, "Daily in 2 minutes"), (1, "Daily in one minute")])
    func eventPhrase(minutes: Int, expected: String) {
        #expect(SpokenTime.eventPhrase(title: "Daily", minutes: minutes) == expected)
    }

    @Test(arguments: [(9, 57, false), (9, 58, true), (9, 59, true), (10, 0, false)])
    func spokenAlertWindow(hour: Int, minute: Int, due: Bool) {
        let result = AlertPlanner.dueSpokenAlerts(
            events: [Fixture.attended(standup)], now: Fixture.at(hour, minute), leadMinutes: 2, alreadySpoken: [])
        #expect(result.isEmpty == !due)
    }

    @Test func spokenOnceAndNeverForQuietEvents() {
        let spoken = AlertPlanner.dueSpokenAlerts(
            events: [Fixture.attended(standup)], now: Fixture.at(9, 59), leadMinutes: 2, alreadySpoken: [standup.id])
        #expect(spoken.isEmpty)
        let silenced = AlertPlanner.dueSpokenAlerts(
            events: [Fixture.attended(standup, override: .silenced)], now: Fixture.at(9, 59), leadMinutes: 2,
            alreadySpoken: [])
        #expect(silenced.isEmpty)
    }
}

@Suite struct SpeechHoursTests {
    @Test(arguments: [(7, 59, false), (8, 0, true), (20, 0, true), (20, 30, false)])
    func daytimeHours(hour: Int, minute: Int, inside: Bool) {
        let hours = SpeechHours(startHour: 8, endHour: 20)
        #expect(hours.contains(Fixture.at(hour, minute), calendar: Fixture.calendar) == inside)
    }

    @Test func hoursAcrossMidnight() {
        let hours = SpeechHours(startHour: 22, endHour: 2)
        #expect(hours.contains(Fixture.at(23, 30), calendar: Fixture.calendar))
        #expect(hours.contains(Fixture.at(1, 0), calendar: Fixture.calendar))
        #expect(!hours.contains(Fixture.at(12, 0), calendar: Fixture.calendar))
    }
}
