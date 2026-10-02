import AVFAudio
import Foundation
import LeveKit

/// Says the time with a system voice. The default voice is Spanish (Spain), the language Smart
/// Desk spoke; any installed Spanish, Portuguese or English voice can replace it.
final class TimeSpeaker {
    struct Voice: Identifiable, Hashable {
        let id: String
        let name: String
    }

    static let defaultLanguage = "es-ES"
    static var defaultVoiceName: String {
        let name = AVSpeechSynthesisVoice(language: defaultLanguage)?.name ?? defaultLanguage
        return String(localized: "\(name) (default)")
    }
    private static let offeredLanguages = ["es", "pt", "en"]

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ date: Date, voiceIdentifier: String?) {
        let voice = Self.voice(voiceIdentifier)
        let language = voice?.language ?? Self.defaultLanguage
        say(SpokenTime.phrase(for: date, languageCode: language, calendar: .current), voice: voice)
    }

    /// "Daily en dos minutos". The synthesizer queues it behind any sentence already playing.
    func speakUpcoming(_ event: CalendarEvent, minutes: Int, voiceIdentifier: String?) {
        let voice = Self.voice(voiceIdentifier)
        let language = voice?.language ?? Self.defaultLanguage
        say(SpokenTime.eventPhrase(title: event.title, minutes: minutes, languageCode: language), voice: voice)
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
            .filter { voice in offeredLanguages.contains { voice.language.hasPrefix($0) } }
            .map { voice in
                let language = locale.localizedString(forIdentifier: voice.language) ?? voice.language
                return Voice(id: voice.identifier, name: "\(voice.name) (\(language))")
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
