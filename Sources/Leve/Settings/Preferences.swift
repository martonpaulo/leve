import Foundation
import LeveKit
import Observation

/// The one owner of Leve's settings. Every key is constant and versioned (`leve.<name>.v1`);
/// changing a value's shape means a new key and a tested migration.
@Observable
final class Preferences {
    static let reminderLeadOptions = [1, 2, 5, 10, 15]
    static let fullScreenLeadOptions = [0, 1, 2, 5]
    static let countdownOptions = [15, 30, 60]
    static let spokenAlertOptions = [1, 2, 5]
    static let breakWorkOptions = [25, 55, 90]
    static let breakLengthOptions = [1, 5, 10]

    /// The values a fresh install starts with, and Restore Defaults returns to.
    enum Default {
        static let reminderLead: Int? = 5
        static let fullScreenLead: Int? = 1
        static let countdown = 30
        static let speechInterval = SpeechInterval.halfHour
        static let spokenAlert: Int? = 2
        static let speechStart = 8
        static let speechEnd = 20
        static let showAllDay = true
        static let showFreeUntil = true
        /// Opt-in: by default the leaf stands alone once the day is done (#10, #16).
        static let showNothingElse = false
        static let breaks = true
        static let breakWork = 55
        static let breakLength = 5
        static let breakSound = true
        /// Opt-in: macOS asks once for each app Leve controls (#2).
        static let pauseMediaOnBreak = false
    }

    private enum Key {
        static let reminderLead = "leve.reminderLeadMinutes.v1"
        static let fullScreenLead = "leve.fullScreenLeadMinutes.v1"
        static let countdown = "leve.countdownMinutes.v1"
        static let speechInterval = "leve.speechIntervalMinutes.v1"
        static let voice = "leve.voiceIdentifier.v1"
        static let urgent = "leve.urgentDelivery.v1"
        static let calendarRules = "leve.calendarRules.v1"
        static let pausedUntil = "leve.pausedUntil.v1"
        static let debugMenu = "leve.debugMenu.v1"
        static let spokenAlert = "leve.spokenAlertMinutes.v1"
        static let speechStart = "leve.speechStartHour.v1"
        static let speechEnd = "leve.speechEndHour.v1"
        static let showAllDay = "leve.showAllDayEvents.v1"
        static let showFreeUntil = "leve.showFreeUntil.v1"
        static let showNothingElse = "leve.showNothingElse.v1"
        static let breaks = "leve.breaks.v1"
        static let breakWork = "leve.breakWorkMinutes.v1"
        static let breakLength = "leve.breakLengthMinutes.v1"
        static let breakSound = "leve.breakSound.v1"
        static let pauseMediaOnBreak = "leve.pauseMediaOnBreak.v1"
    }

    /// `-1` is stored for "off", so a missing key can still mean the default.
    private static let offValue = -1

    @ObservationIgnored private let defaults: UserDefaults

    /// Minutes before an event for its notification; nil means no notification.
    var reminderLeadMinutes: Int? {
        didSet { store(reminderLeadMinutes, Key.reminderLead) }
    }
    /// Minutes before an event for the full-screen alert; 0 means at the start, nil means never.
    var fullScreenLeadMinutes: Int? {
        didSet { store(fullScreenLeadMinutes, Key.fullScreenLead) }
    }
    /// How close an event must be before the menu bar counts down to it.
    var countdownMinutes: Int {
        didSet { defaults.set(countdownMinutes, forKey: Key.countdown) }
    }
    var speechInterval: SpeechInterval {
        didSet { defaults.set(speechInterval.rawValue, forKey: Key.speechInterval) }
    }
    /// Minutes before an event for its spoken warning; nil means none.
    var spokenAlertMinutes: Int? {
        didSet { store(spokenAlertMinutes, Key.spokenAlert) }
    }
    /// The spoken time is said only from this hour to `speechEndHour`, both included.
    var speechStartHour: Int {
        didSet { defaults.set(speechStartHour, forKey: Key.speechStart) }
    }
    var speechEndHour: Int {
        didSet { defaults.set(speechEndHour, forKey: Key.speechEnd) }
    }
    var speechHours: SpeechHours {
        SpeechHours(startHour: speechStartHour, endHour: speechEndHour)
    }
    /// Writes "Free until …" in the menu bar when no event is close; off, the leaf stands alone.
    var showFreeUntil: Bool {
        didSet { defaults.set(showFreeUntil, forKey: Key.showFreeUntil) }
    }
    /// Writes "Nothing else today" in the menu bar once no alerting event is left; off, the leaf
    /// stands alone.
    var showNothingElse: Bool {
        didSet { defaults.set(showNothingElse, forKey: Key.showNothingElse) }
    }
    /// Lists all-day events in their own section of the menu. They never alert.
    var showAllDayEvents: Bool {
        didSet { defaults.set(showAllDayEvents, forKey: Key.showAllDay) }
    }
    /// Asks for a break after `breakWorkMinutes` of work.
    var breaks: Bool {
        didSet { defaults.set(breaks, forKey: Key.breaks) }
    }
    var breakWorkMinutes: Int {
        didSet { defaults.set(breakWorkMinutes, forKey: Key.breakWork) }
    }
    var breakLengthMinutes: Int {
        didSet { defaults.set(breakLengthMinutes, forKey: Key.breakLength) }
    }
    /// A quiet tone when a break starts and ends.
    var breakSound: Bool {
        didSet { defaults.set(breakSound, forKey: Key.breakSound) }
    }
    /// Pauses Music, Spotify, TV and the browsers' media when a break starts; never resumes them.
    var pauseMediaOnBreak: Bool {
        didSet { defaults.set(pauseMediaOnBreak, forKey: Key.pauseMediaOnBreak) }
    }
    var breakSchedule: BreakSchedule? {
        breaks ? BreakSchedule(workMinutes: breakWorkMinutes, breakMinutes: breakLengthMinutes) : nil
    }
    /// nil means the default English voice.
    var voiceIdentifier: String? {
        didSet { defaults.set(voiceIdentifier, forKey: Key.voice) }
    }
    var urgentDelivery: Bool {
        didSet { defaults.set(urgentDelivery, forKey: Key.urgent) }
    }
    private(set) var calendarRules: [String: CalendarRule] {
        didSet { defaults.set(calendarRules.mapValues(\.rawValue), forKey: Key.calendarRules) }
    }
    /// Shows the Debug submenu, for trying the alerts without real events.
    var debugMenu: Bool {
        didSet { defaults.set(debugMenu, forKey: Key.debugMenu) }
    }
    private(set) var pausedUntil: Date? {
        didSet { defaults.set(pausedUntil, forKey: Key.pausedUntil) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reminderLeadMinutes = Self.read(
            defaults, Key.reminderLead, options: Self.reminderLeadOptions, fallback: Default.reminderLead)
        fullScreenLeadMinutes = Self.read(
            defaults, Key.fullScreenLead, options: Self.fullScreenLeadOptions, fallback: Default.fullScreenLead)
        let countdown = defaults.object(forKey: Key.countdown) as? Int ?? Default.countdown
        countdownMinutes = Self.countdownOptions.contains(countdown) ? countdown : Default.countdown
        let interval = defaults.object(forKey: Key.speechInterval) as? Int
        speechInterval = interval.flatMap(SpeechInterval.init(rawValue:)) ?? Default.speechInterval
        voiceIdentifier = defaults.string(forKey: Key.voice)
        urgentDelivery = defaults.bool(forKey: Key.urgent)
        let rawRules = defaults.dictionary(forKey: Key.calendarRules) as? [String: String] ?? [:]
        calendarRules = rawRules.compactMapValues(CalendarRule.init(rawValue:))
        pausedUntil = defaults.object(forKey: Key.pausedUntil) as? Date
        debugMenu = defaults.bool(forKey: Key.debugMenu)
        spokenAlertMinutes = Self.read(
            defaults, Key.spokenAlert, options: Self.spokenAlertOptions, fallback: Default.spokenAlert)
        speechStartHour = Self.hour(defaults, Key.speechStart, fallback: Default.speechStart)
        speechEndHour = Self.hour(defaults, Key.speechEnd, fallback: Default.speechEnd)
        showAllDayEvents = defaults.object(forKey: Key.showAllDay) as? Bool ?? Default.showAllDay
        showFreeUntil = defaults.object(forKey: Key.showFreeUntil) as? Bool ?? Default.showFreeUntil
        showNothingElse = defaults.object(forKey: Key.showNothingElse) as? Bool ?? Default.showNothingElse
        breaks = defaults.object(forKey: Key.breaks) as? Bool ?? Default.breaks
        breakWorkMinutes =
            Self.read(defaults, Key.breakWork, options: Self.breakWorkOptions, fallback: Default.breakWork)
            ?? Default.breakWork
        breakLengthMinutes =
            Self.read(defaults, Key.breakLength, options: Self.breakLengthOptions, fallback: Default.breakLength)
            ?? Default.breakLength
        breakSound = defaults.object(forKey: Key.breakSound) as? Bool ?? Default.breakSound
        pauseMediaOnBreak = defaults.object(forKey: Key.pauseMediaOnBreak) as? Bool ?? Default.pauseMediaOnBreak
    }

    /// Returns every setting to its default. The pause, the debug menu, macOS permissions and launch
    /// at login stay as they are.
    func restoreDefaults() {
        reminderLeadMinutes = Default.reminderLead
        fullScreenLeadMinutes = Default.fullScreenLead
        countdownMinutes = Default.countdown
        speechInterval = Default.speechInterval
        spokenAlertMinutes = Default.spokenAlert
        speechStartHour = Default.speechStart
        speechEndHour = Default.speechEnd
        showAllDayEvents = Default.showAllDay
        showFreeUntil = Default.showFreeUntil
        showNothingElse = Default.showNothingElse
        breaks = Default.breaks
        breakWorkMinutes = Default.breakWork
        breakLengthMinutes = Default.breakLength
        breakSound = Default.breakSound
        pauseMediaOnBreak = Default.pauseMediaOnBreak
        voiceIdentifier = nil
        urgentDelivery = false
        calendarRules = [:]
    }

    func rule(for calendarID: String) -> CalendarRule {
        calendarRules[calendarID] ?? .defaultRule
    }

    func setRule(_ rule: CalendarRule, for calendarID: String) {
        calendarRules[calendarID] = rule == .defaultRule ? nil : rule
    }

    func isPaused(at now: Date) -> Bool {
        guard let pausedUntil else { return false }
        return now < pausedUntil
    }

    func pause(until date: Date) {
        pausedUntil = date
    }

    func resume() {
        pausedUntil = nil
    }

    private func store(_ minutes: Int?, _ key: String) {
        defaults.set(minutes ?? Self.offValue, forKey: key)
    }

    private static func hour(_ defaults: UserDefaults, _ key: String, fallback: Int) -> Int {
        guard let value = defaults.object(forKey: key) as? Int, (0...23).contains(value) else { return fallback }
        return value
    }

    /// A stored value outside the offered options falls back, so no picker is left without a choice.
    private static func read(_ defaults: UserDefaults, _ key: String, options: [Int], fallback: Int?) -> Int? {
        guard let value = defaults.object(forKey: key) as? Int else { return fallback }
        if value == offValue { return nil }
        return options.contains(value) ? value : fallback
    }
}
