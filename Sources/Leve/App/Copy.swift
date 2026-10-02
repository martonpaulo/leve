import Foundation
import LeveKit

/// Every visible word of Leve, in one place. English only for now (docs/product.md); each value
/// goes through `String(localized:)`, so a String Catalog can translate them later without
/// touching the views.
enum Copy {
    // MARK: Menu bar

    static let untitledEvent = String(localized: "Untitled event")
    static let appName = String(localized: "Leve")

    static func status(_ status: MenuBarStatus, now: Date) -> String {
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
    static let silencedSuffix = String(localized: "(silenced)")

    static func eventRow(_ event: CalendarEvent, silenced: Bool) -> String {
        let start = event.isAllDay ? allDay : time(event.start)
        let row = "\(start)  \(event.title)"
        return silenced ? "\(row) \(silencedSuffix)" : row
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

    static let silenceEvent = String(localized: "Silence This Event")
    static let unsilenceEvent = String(localized: "Turn Alerts Back On")
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
        let minutes = max(0, Int((event.start.timeIntervalSince(now) / 60).rounded(.up)))
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
    static let alertsFooter = String(
        localized:
            "Full screen covers your screen until you join or close it. Press Esc to close it.")
    static let off = String(localized: "Off")
    static let atStart = String(localized: "When it starts")

    static func minutesBefore(_ minutes: Int) -> String {
        String(localized: "\(minutes) min before")
    }

    static let menuBarSection = String(localized: "Menu bar")
    static let countdown = String(localized: "Count down from")

    static func minutes(_ minutes: Int) -> String {
        String(localized: "\(minutes) min")
    }

    static let speechSection = String(localized: "Spoken time")
    static let speakTime = String(localized: "Say the time")
    static let voice = String(localized: "Voice")
    static let preview = String(localized: "Preview")
    static let speechFooter = String(localized: "Leve stays quiet during events and while alerts are paused.")

    static func speechInterval(_ interval: SpeechInterval) -> String {
        switch interval {
        case .off: off
        case .quarterHour: String(localized: "Every 15 minutes")
        case .halfHour: String(localized: "Every 30 minutes")
        case .hour: String(localized: "Every hour")
        }
    }

    static let notificationsOff = String(localized: "Notifications for Leve are off in System Settings.")
    static let openNotificationSettings = String(localized: "Open Notification Settings…")
    static let calendarsFooter = String(localized: "Choose how much attention each calendar gets.")

    static func rule(_ rule: CalendarRule) -> String {
        switch rule {
        case .everything: String(localized: "All alerts")
        case .noFullScreen: String(localized: "No full screen")
        case .menuOnly: String(localized: "Menu only")
        case .ignore: String(localized: "Ignore")
        }
    }

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

    static func released(_ date: String) -> String {
        String(localized: "Released \(date)")
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
