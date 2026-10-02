import AppKit

/// Deep links into System Settings, in one place.
enum SystemSettings {
    static func openCalendarPrivacy() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
    }

    static func openNotifications() {
        let id = Bundle.main.bundleIdentifier ?? ""
        open("x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")
    }

    private static func open(_ link: String) {
        if let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
    }
}
