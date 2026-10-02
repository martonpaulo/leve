import Foundation
import LeveKit

/// Every visible word of Leve, in one place. English only for now (docs/product.md); each value
/// goes through `String(localized:)`, so a String Catalog can translate them later without
/// touching the views.
enum Copy {
    // MARK: Menu bar

    static let untitledEvent = String(localized: "Untitled event")
    static let appName = String(localized: "Leve")

    static func status(_ status: MenuBarStatus) -> String {
        switch status {
        case .clear:
            String(localized: "Nothing else today")
        case .freeUntil(let date):
            String(localized: "Free until \(time(date))")
        case .upcoming(let title, let minutes):
            String(localized: "\(short(title)) in \(minutes) min")
        case .ongoing(let title, let minutesLeft):
            String(localized: "\(short(title)) · \(minutesLeft) min left")
        }
    }

    static func pausedUntil(_ date: Date) -> String {
        String(localized: "Alerts paused until \(time(date))")
    }

    static let calendarAccessNeeded = String(localized: "Leve needs access to your calendars")
    static let allowCalendarAccess = String(localized: "Allow Calendar Access…")
    static let openPrivacySettings = String(localized: "Open Privacy Settings…")
    static let today = String(localized: "Today")
    static let noMoreEvents = String(localized: "No more events today")
    static let allDay = String(localized: "All day")
    static func eventRow(_ event: CalendarEvent, override: EventOverride?) -> String {
        let start = event.isAllDay ? allDay : time(event.start)
        let row = "\(start)  \(event.title)"
        switch override {
        case .silenced: return String(localized: "\(row) (alerts off)")
        case .noFullScreen: return String(localized: "\(row) (no full screen)")
        case .hidden, nil: return row
        }
    }

    static func timeRange(_ event: CalendarEvent) -> String {
        event.isAllDay ? allDay : "\(time(event.start)) – \(time(event.end))"
    }

    static func join(_ provider: MeetingProvider) -> String {
        switch provider {
        case .googleMeet: String(localized: "Join Google Meet")
        case .microsoftTeams: String(localized: "Join Microsoft Teams")
        case .zoom: String(localized: "Join Zoom")
        case .webex: String(localized: "Join Webex")
        case .other: String(localized: "Open Link")
        }
    }

    // One word per attention level everywhere: alerts on or off, full screen or not, hidden.
    static let alertsOffForEvent = String(localized: "Turn Off Alerts for This Event")
    static let alertsBackOn = String(localized: "Turn Alerts Back On")
    static let noFullScreenInMenu = String(localized: "Don’t Show Full Screen")
    static let fullScreenBackOn = String(localized: "Show Full Screen Again")
    static let hideEvent = String(localized: "Hide This Event")

    static func showHidden(_ count: Int) -> String {
        String(localized: "Show Hidden Events (\(count))")
    }

    static let debug = String(localized: "Debug")
    static let debugMenu = String(localized: "Show debug menu")
    static let simulateEvent = String(localized: "Simulate Event in 2 Minutes")
    static let showFullScreenNow = String(localized: "Show Full Screen Now")
    static let sendTestNotification = String(localized: "Send Test Notification")
    static let sayTimeNow = String(localized: "Say the Time Now")
    static let clearSimulated = String(localized: "Clear Simulated Events")

    static func simulatedEventTitle(_ number: Int) -> String {
        String(localized: "Test event \(number)")
    }

    static let pause = String(localized: "Pause Alerts")
    static let pauseThirtyMinutes = String(localized: "For 30 Minutes")
    static let pauseOneHour = String(localized: "For 1 Hour")
    static let pauseUntilTomorrow = String(localized: "Until Tomorrow")
    static let resume = String(localized: "Resume Alerts")
    static let settings = String(localized: "Settings…")
    static let quit = String(localized: "Quit Leve")

    // MARK: Notifications and full screen

    static func startsIn(_ event: CalendarEvent, now: Date) -> String {
        let minutes = event.minutesUntilStart(from: now)
        if minutes == 0 {
            return String(localized: "Starting now · \(timeRange(event))")
        }
        return String(localized: "Starts in \(minutes) min · \(timeRange(event))")
    }

    static let joinAction = String(localized: "Join")
    static let close = String(localized: "Close")
    static let noFullScreenForEvent = String(localized: "Don’t Show Full Screen for This Event")

    // MARK: Settings

    static let general = String(localized: "General")
    static let calendars = String(localized: "Calendars")
    static let about = String(localized: "About")

    static let launchAtLogin = String(localized: "Open Leve at login")
    static let loginNeedsApproval = String(localized: "Allow Leve in System Settings to open it at login.")
    static let openLoginItems = String(localized: "Open Login Items…")
    static let loginUnavailable = String(localized: "Available only in the installed app.")
    static let loginFailed = String(localized: "macOS did not change the login item.")

    static let alertsSection = String(localized: "Before an event")
    static let notification = String(localized: "Notification")
    static let fullScreen = String(localized: "Full screen")
    static let urgentDelivery = String(localized: "Show notifications during Focus")
    static let alertsFooter = String(localized: "Full screen covers every display until you join or close it (Esc).")
    static let off = String(localized: "Off")
    static let atStart = String(localized: "When it starts")

    static func minutesBefore(_ minutes: Int) -> String {
        String(localized: "\(minutes) min before")
    }

    static let menuBarSection = String(localized: "Menu bar")
    static let countdown = String(localized: "Show countdown")

    static func minutes(_ minutes: Int) -> String {
        String(localized: "\(minutes) min")
    }

    static let speechSection = String(localized: "Spoken time")
    static let speakTime = String(localized: "Say the time")
    static let voice = String(localized: "Voice")
    static let speechHours = String(localized: "Between")
    static let speechHoursTo = String(localized: "and")
    static let speechHoursFrom = String(localized: "From")
    static let speechHoursUntil = String(localized: "To")

    static func defaultVoice(_ name: String) -> String {
        String(localized: "\(name) (default)")
    }
    static let sayUpcoming = String(localized: "Say upcoming events")

    static func hour(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return time(date)
    }
    static let preview = String(localized: "Preview")
    static let speechFooter = String(
        localized: "Leve stays quiet during events and while alerts are paused. Upcoming events are said at any hour.")

    static func speechInterval(_ interval: SpeechInterval) -> String {
        switch interval {
        case .off: off
        case .quarterHour: String(localized: "Every 15 minutes")
        case .halfHour: String(localized: "Every 30 minutes")
        case .hour: String(localized: "Every hour")
        }
    }

    static let calendarsHeader = String(
        localized:
            "All alerts: countdown, notification and full screen. No full screen: countdown and notification. No alerts: listed only. Hidden: not shown."
    )

    static func rule(_ rule: CalendarRule) -> String {
        switch rule {
        case .everything: String(localized: "All alerts")
        case .noFullScreen: String(localized: "No full screen")
        case .menuOnly: String(localized: "No alerts")
        case .ignore: String(localized: "Hidden")
        }
    }

    // MARK: Settings: permissions, restore and quit

    static let permissions = String(localized: "Permissions")
    static let calendarPermission = String(localized: "Calendar")
    static let calendarPermissionNote = String(localized: "Needed to read today’s events.")
    static let notificationPermission = String(localized: "Notifications")
    static let notificationPermissionNote = String(localized: "Needed to warn you before events.")
    static let allowed = String(localized: "Allowed")
    static let notAllowed = String(localized: "Not allowed")
    static let openSystemSettings = String(localized: "Open System Settings…")
    static let restoreDefaultsButton = String(localized: "Restore Defaults…")
    static let restoreDefaultsQuestion = String(localized: "Restore all Leve settings?")
    static let restoreDefaultsMessage = String(
        localized:
            "Alerts, the countdown, spoken time and calendar choices return to their original values. Permissions, launch at login and per-event choices are unchanged."
    )
    static let restoreDefaults = String(localized: "Restore Defaults")
    static let cancel = String(localized: "Cancel")
    static let quitButton = String(localized: "Quit Leve…")
    static let quitQuestion = String(localized: "Quit Leve?")
    static let quitMessage = String(localized: "Leve stops showing your events and alerts until you open it again.")
    static let debugFooter = String(localized: "Adds a Debug menu to try the alerts without real events.")
    static let developer = String(localized: "Developer")

    static let noCalendars = String(localized: "No calendars found on this Mac.")
    static let aboutDescription = String(
        localized:
            "Know when your next event is, hear the time, and never miss a meeting while you focus.")

    static func version(_ version: String) -> String {
        String(localized: "Version \(version)")
    }

    static func version(_ version: String, build: String) -> String {
        String(localized: "Version \(version) (\(build))")
    }

    /// "Version 0.1.0 (100) · 3 October 2026".
    static func versionLine(_ version: String, released: String?) -> String {
        guard let released else { return version }
        return String(localized: "\(version) · \(released)")
    }

    static let copyright = String(localized: "© 2026 Marton Paulo. MIT License.")

    // MARK: Formatting

    /// The menu bar has little room: a long title is cut to keep the countdown visible.
    static func short(_ title: String, limit: Int = 24) -> String {
        title.count <= limit ? title : String(title.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
