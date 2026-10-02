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

/// The sentences Leve speaks, in English.
public enum SpokenTime {
    private static let locale = Locale(identifier: "en_US")

    /// "It's 10 AM" on the hour, "It's 10:30 AM" otherwise.
    public static func phrase(for date: Date, calendar: Calendar) -> String {
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        style = calendar.component(.minute, from: date) == 0 ? style.hour() : style.hour().minute()
        return "It's \(date.formatted(style))"
    }

    /// The sentence spoken shortly before an event: "Standup in 2 minutes".
    public static func eventPhrase(title: String, minutes: Int) -> String {
        minutes == 1 ? "\(title) in one minute" : "\(title) in \(minutes) minutes"
    }
}
