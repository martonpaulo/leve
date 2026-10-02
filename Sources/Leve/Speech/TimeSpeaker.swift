import AVFAudio
import Foundation
import LeveKit

/// Says the time and upcoming events in English with a system voice; any installed English voice
/// can replace the default one.
final class TimeSpeaker {
    struct Voice: Identifiable, Hashable {
        let id: String
        let name: String
    }

    static let defaultLanguage = "en-US"
    /// Listing every installed voice is costly, so it happens once per launch.
    static let englishVoices = availableVoices()
    static var defaultVoiceName: String {
        let name = AVSpeechSynthesisVoice(language: defaultLanguage)?.name ?? defaultLanguage
        return Copy.defaultVoice(name)
    }
    private static let offeredLanguage = "en"

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ date: Date, voiceIdentifier: String?) {
        say(SpokenTime.phrase(for: date, calendar: .current), voice: Self.voice(voiceIdentifier))
    }

    /// "Standup in 2 minutes". The synthesizer queues it behind any sentence already playing.
    func speakUpcoming(_ event: CalendarEvent, minutes: Int, voiceIdentifier: String?) {
        say(SpokenTime.eventPhrase(title: event.title, minutes: minutes), voice: Self.voice(voiceIdentifier))
    }

    private func say(_ text: String, voice: AVSpeechSynthesisVoice?) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }

    private static func voice(_ identifier: String?) -> AVSpeechSynthesisVoice? {
        identifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: defaultLanguage)
    }

    static func availableVoices() -> [Voice] {
        let locale = Locale.current
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(offeredLanguage) }
            .map { voice in
                let language = locale.localizedString(forIdentifier: voice.language) ?? voice.language
                return Voice(id: voice.identifier, name: "\(voice.name) (\(language))")
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
