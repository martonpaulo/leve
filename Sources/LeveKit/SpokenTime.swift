import Foundation

/// How often Leve says the time.
public enum SpeechInterval: Int, Sendable, CaseIterable, Codable {
    case off = 0
    case quarterHour = 15
    case halfHour = 30
    case hour = 60

    var boundaryMinutes: [Int] {
        switch self {
        case .off: []
        case .quarterHour: [0, 15, 30, 45]
        case .halfHour: [0, 30]
        case .hour: [0]
        }
    }

    /// True when `date` falls on one of this interval's boundaries, such as 10:30 for half hours.
    public func isBoundary(_ date: Date, calendar: Calendar) -> Bool {
        boundaryMinutes.contains(calendar.component(.minute, from: date))
    }
}

/// The hours in which Leve says the time, such as 8:00 to 20:00. Both ends are included, so the
/// last announcement is the one at the end hour. A start after the end spans midnight.
public struct SpeechHours: Sendable, Equatable {
    public let startHour: Int
    public let endHour: Int

    public init(startHour: Int, endHour: Int) {
        self.startHour = startHour
        self.endHour = endHour
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let start = startHour * 60
        let end = endHour * 60
        if start <= end {
            return start <= minute && minute <= end
        }
        return minute >= start || minute <= end
    }
}

/// The sentence spoken at a time boundary.
public enum SpokenTime {
    /// A natural Spanish phrase ("Son las diez y media de la mañana") for a Spanish voice, ported
    /// from Smart Desk; any other language gets the locale's own short time, which the voice reads.
    public static func phrase(for date: Date, languageCode: String, calendar: Calendar) -> String {
        if languageCode.lowercased().hasPrefix("es") {
            return spanish(for: date, calendar: calendar)
        }
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.locale = Locale(identifier: languageCode)
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    /// The sentence spoken shortly before an event: "Daily en dos minutos".
    public static func eventPhrase(title: String, minutes: Int, languageCode: String) -> String {
        let code = languageCode.lowercased()
        if code.hasPrefix("es") {
            let amount = minutes == 1 ? "un minuto" : "\(minuteWords[minutes] ?? String(minutes)) minutos"
            return "\(title) en \(amount)"
        }
        if code.hasPrefix("pt") {
            return minutes == 1 ? "\(title) em um minuto" : "\(title) em \(minutes) minutos"
        }
        return minutes == 1 ? "\(title) in one minute" : "\(title) in \(minutes) minutes"
    }

    static func spanish(for date: Date, calendar: Calendar) -> String {
        let hour24 = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let hour12 = twelveHour(hour24)
        let period = dayPeriod(hour24)

        if minute == 0 {
            return "\(prefix(hour12)) \(hourWords[hour12]) \(period)"
        }
        if minute <= 30 {
            let minutes: String
            switch minute {
            case 15: minutes = "y cuarto"
            case 30: minutes = "y media"
            default: minutes = "y \(minuteWords[minute] ?? String(minute))"
            }
            return "\(prefix(hour12)) \(hourWords[hour12]) \(minutes) \(period)"
        }
        let nextHour = twelveHour(hour12 + 1)
        let remaining = 60 - minute
        let minutes = remaining == 15 ? "menos cuarto" : "menos \(minuteWords[remaining] ?? String(remaining))"
        return "\(prefix(nextHour)) \(hourWords[nextHour]) \(minutes) \(period)"
    }

    private static func prefix(_ hour: Int) -> String {
        hour == 1 ? "Es la" : "Son las"
    }

    private static func twelveHour(_ hour: Int) -> Int {
        let remainder = hour % 12
        return remainder == 0 ? 12 : remainder
    }

    private static func dayPeriod(_ hour24: Int) -> String {
        switch hour24 {
        case 1..<12: "de la mañana"
        case 12..<21: "de la tarde"
        default: "de la noche"
        }
    }

    private static let hourWords = [
        "", "una", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "once", "doce",
    ]

    private static let minuteWords: [Int: String] = [
        1: "uno", 2: "dos", 3: "tres", 4: "cuatro", 5: "cinco", 6: "seis", 7: "siete", 8: "ocho", 9: "nueve",
        10: "diez", 11: "once", 12: "doce", 13: "trece", 14: "catorce", 16: "dieciséis", 17: "diecisiete",
        18: "dieciocho", 19: "diecinueve", 20: "veinte", 21: "veintiuno", 22: "veintidós", 23: "veintitrés",
        24: "veinticuatro", 25: "veinticinco", 26: "veintiséis", 27: "veintisiete", 28: "veintiocho",
        29: "veintinueve",
    ]
}
