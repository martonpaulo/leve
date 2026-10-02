import AppKit
import LeveKit
import OSLog
import Observation
import UserNotifications

/// Keeps the pending notifications equal to the planned reminders. It removes only its own
/// requests, identified by a prefix, and adds a Join button when the event has a call link.
@Observable
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    nonisolated private static let prefix = "leve.reminder."
    nonisolated private static let category = "leve.event"
    nonisolated private static let joinAction = "leve.join"
    nonisolated private static let linkKey = "link"

    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    @ObservationIgnored private let logger = Logger(subsystem: "com.martonpaulo.leve", category: "reminders")
    /// True when this Mac lets Leve break through Focus; nil until the settings are read.
    private(set) var supportsUrgentDelivery: Bool?
    /// False when notifications for Leve are off in System Settings; nil until read.
    private(set) var notificationsAllowed: Bool?

    override init() {
        super.init()
        center.delegate = self
        let join = UNNotificationAction(identifier: Self.joinAction, title: Copy.joinAction, options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [join], intentIdentifiers: [])
        ])
    }

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshSettings()
    }

    /// Reads the current permission; Settings calls it when it appears and when Leve becomes active.
    func refreshSettings() async {
        let settings = await center.notificationSettings()
        supportsUrgentDelivery = settings.timeSensitiveSetting != .notSupported
        notificationsAllowed = settings.authorizationStatus == .authorized
        logger.notice(
            "Notification status \(settings.authorizationStatus.rawValue, privacy: .public), alerts \(settings.alertSetting.rawValue, privacy: .public), time-sensitive \(settings.timeSensitiveSetting.rawValue, privacy: .public)"
        )
    }

    func replace(with reminders: [PlannedReminder], urgent: Bool, now: Date) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        // Already on screen or in Notification Center: never deliver the same reminder twice.
        let delivered = Set(await center.deliveredNotifications().map(\.request.identifier))

        for reminder in reminders where !delivered.contains(Self.prefix + reminder.event.id) {
            let content = Self.content(for: reminder.event, at: reminder.fireDate, urgent: urgent)
            let delay = max(1, reminder.fireDate.timeIntervalSince(now))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.prefix + reminder.event.id,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                logger.error("Could not schedule a reminder: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Delivers one notification for `event` now, outside the plan; the Debug menu uses it.
    func sendNow(_ event: CalendarEvent) async {
        let content = Self.content(for: event, at: .now, urgent: false)
        let request = UNNotificationRequest(identifier: "leve.debug." + event.id, content: content, trigger: nil)
        do {
            try await center.add(request)
        } catch {
            logger.error("Could not send a test notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// One notification's content: the title, when it starts, and a Join button for a call link.
    private static func content(for event: CalendarEvent, at date: Date, urgent: Bool) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = Copy.startsIn(event, now: date)
        content.sound = .default
        content.interruptionLevel = urgent ? .timeSensitive : .active
        if let link = event.link {
            content.categoryIdentifier = category
            content.userInfo = [linkKey: link.url.absoluteString]
        }
        return content
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        guard
            response.actionIdentifier == Self.joinAction
                || response.actionIdentifier == UNNotificationDefaultActionIdentifier,
            let link = content.userInfo[Self.linkKey] as? String,
            let url = URL(string: link)
        else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }
}
