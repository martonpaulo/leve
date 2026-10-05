import AppKit

/// Deep links into System Settings, in one place.
enum SystemSettings {
    static func openCalendarPrivacy() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
    }

    /// Privacy & Security › Automation, where the user allows Leve to control an app (#12). Apple
    /// does not document this URL, so the copy also names the path.
    static func openAutomation() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
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
