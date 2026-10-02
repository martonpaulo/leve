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
        guard !synthesizer.isSpeaking else { return }
        let voice =
            voiceIdentifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: Self.defaultLanguage)
        let language = voice?.language ?? Self.defaultLanguage
        let utterance = AVSpeechUtterance(
            string: SpokenTime.phrase(for: date, languageCode: language, calendar: .current)
        )
        utterance.voice = voice
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
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
