import Foundation
import LeveKit
import Testing

@Suite struct SpokenTimeTests {
    @Test(arguments: [
        (10, 0, "Son las diez de la mañana"),
        (10, 30, "Son las diez y media de la mañana"),
        (13, 15, "Es la una y cuarto de la tarde"),
        (12, 45, "Es la una menos cuarto de la tarde"),
        (21, 0, "Son las nueve de la noche"),
        (0, 0, "Son las doce de la noche"),
    ])
    func spanishPhrase(hour: Int, minute: Int, expected: String) {
        let phrase = SpokenTime.phrase(for: Fixture.at(hour, minute), languageCode: "es-ES", calendar: Fixture.calendar)
        #expect(phrase == expected)
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
