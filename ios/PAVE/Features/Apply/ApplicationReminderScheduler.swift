import PAVECore
import UserNotifications

/// Plans the notifications of applications that asked for them, on this device. They are planned again from all
/// applications every time one changes, so what was turned off or finished is taken away.
@MainActor
enum ApplicationReminderScheduler {
    private static let prefix = "application."

    /// Asks for permission when the user turns reminders on, not before.
    static func requestAccess() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func sync(_ drafts: [ApplicationDraft], now: Date = .now) {
        ApplicationWidgetSnapshot.update(drafts: drafts)
        Task {
            let center = UNUserNotificationCenter.current()
            let planned = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: planned)
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else { return }
            for reminder in ApplicationReminders.plan(drafts, now: now) {
                let content = UNMutableNotificationContent()
                content.title = ApplyMessages.reminderTitle(reminder.kind)
                content.body = ApplyMessages.reminderBody(reminder)
                content.sound = .default
                content.threadIdentifier = "application"
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
                try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
            }
        }
    }
}
