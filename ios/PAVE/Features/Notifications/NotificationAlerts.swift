import BackgroundTasks
import UIKit
import UserNotifications

/// Meldingen outside the Meldingen screen: the badge on the app icon, and a banner when something new arrives while
/// PAVE is in the background.
///
/// This is **local**, not push: iOS only delivers push through APNs, which needs a paid Apple Developer account. Until
/// there is one, PAVE asks iOS for a short background refresh now and then (`BGAppRefreshTask`) and shows a local
/// notification for what is new. iOS decides how often that runs, so a melding can take a while to show up while the
/// app is closed. When the app is open, `NotificationsModel` shows an in-app banner instead.
///
/// A banner only ever carries the title of the melding ("Bewijs geverifieerd"), never the evidence, the organisation
/// or any chat text, like everywhere else for meldingen (docs/verificatie.md).
///
/// New e-mail gets a banner too: who it is from and the subject, as in Mail, never the text. A muted conversation gets
/// none, and a locked one only says that there is new mail. The mail is fetched on this iPhone, with the credentials
/// in the Keychain; nothing goes through PAVE's server.
@MainActor
enum NotificationAlerts {
    /// Instellingen › Meldingen. On unless switched off.
    static let settingKey = "notificationAlerts"
    static let refreshTaskID = "nl.fontys.pave.notifications-refresh"
    private static let seenKey = "notificationSeenIDs"

    /// Set by `AppState`: someone tapped a banner, so PAVE opens on Meldingen once it is unlocked; for e-mail, with the
    /// conversation's id so it opens that conversation.
    static var onTap: ((_ emailThreadID: String?) -> Void)?
    static let emailThreadKey = "emailThreadID"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    // MARK: Permission

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Shows iOS's own question. Call it from something the person chose, not at launch.
    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    // MARK: Badge

    static func setBadge(_ count: Int) {
        guard isEnabled else {
            UNUserNotificationCenter.current().setBadgeCount(0)
            return
        }
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    // MARK: What was already shown

    static var seenIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: seenKey) }
    }

    static func forgetEverything() {
        UserDefaults.standard.removeObject(forKey: seenKey)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(0)
        EmailPhotoStore.forgetAll()
    }

    // MARK: Local banner

    static func announce(_ notification: PaveNotification) async {
        guard isEnabled, await status() == .authorized else { return }
        let content = UNMutableNotificationContent()
        if notification.kind == .email, let threadID = notification.emailThreadID {
            if notification.emailIsLocked {
                content.title = "Nieuwe e-mail".translated
                content.body = "In een vergrendeld gesprek".translated
            } else {
                content.title = notification.personName
                // The subject, as Mail shows it; without one only the name.
                content.body = notification.title.translated
                // Their photo beside it, when your contacts have one; a locked conversation never shows who it is.
                if let person = notification.emailPeople.first, let photo = await photoAttachment(for: person) {
                    content.attachments = [photo]
                }
            }
            content.threadIdentifier = notification.id
            content.userInfo = [emailThreadKey: threadID]
        } else {
            content.title = notification.title.translated
            content.threadIdentifier = "meldingen"
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: notification.id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// The contact photo as a file iOS can show with the melding; nil when there is no photo.
    private static func photoAttachment(for person: EmailAddress) async -> UNNotificationAttachment? {
        // The photo Meldingen showed (your PAVE photo, a contact's), otherwise straight from your contacts.
        var data = EmailPhotoStore.data(for: person.address)
        if data == nil { data = await EmailContactCard.lookup(person.address)?.photo?.jpegData(compressionQuality: 0.85) }
        guard let data else { return nil }
        // iOS moves the file into its own store, so each melding gets its own copy.
        let url = FileManager.default.temporaryDirectory.appending(path: "melding-\(UUID().uuidString).jpg")
        do {
            try data.write(to: url)
            return try UNNotificationAttachment(identifier: "photo", url: url, options: [
                UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg",
            ])
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    // MARK: Background refresh

    /// Call once at launch, before the app finishes launching.
    static func registerBackgroundRefresh() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                scheduleRefresh()
                let work = Task { @MainActor in await refreshInBackground() }
                task.expirationHandler = { work.cancel() }
                await work.value
                task.setTaskCompleted(success: !work.isCancelled)
            }
        }
    }

    /// Asks iOS for a refresh no sooner than 15 minutes from now. Safe to call again and again.
    static func scheduleRefresh() {
        guard isEnabled, AppState.isSignedIn() else { return }
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func refreshInBackground() async {
        guard isEnabled, AppState.isSignedIn() else { return }
        async let meldingen = refreshMeldingen()
        async let mail = refreshEmail()
        let (unreadMeldingen, unreadMail) = await (meldingen, mail)
        if unreadMeldingen != nil || unreadMail != nil {
            setBadge((unreadMeldingen ?? 0) + (unreadMail ?? 0))
        }
    }

    /// The unread meldingen, or nil when they could not be fetched.
    private static func refreshMeldingen() async -> Int? {
        guard let service = NotificationsServiceFactory.make(auth: AuthServiceFactory.make()),
              let (_, rows) = try? await service.inbox() else { return nil }
        let seen = seenIDs
        let live = rows.filter { $0.deletedAt == nil }
        // The first run only learns what is there, so nobody gets their whole inbox as banners.
        if !seen.isEmpty || UserDefaults.standard.object(forKey: seenKey) != nil {
            for notification in live where notification.isUnread && !seen.contains(notification.id) {
                await announce(notification)
            }
        }
        seenIDs = Set(rows.map(\.id))
        return live.filter(\.isUnread).count
    }

    /// New mail since PAVE last looked, in the app or here; nil without a connected mailbox or when it failed.
    private static func refreshEmail() async -> Int? {
        let email = EmailModel()
        guard email.hasAccounts else { return nil }
        await email.refresh(previews: false)
        guard email.problem == nil else { return nil }
        for notification in email.arrivals { await announce(notification) }
        return email.unreadCount
    }
}

/// Shows nothing while PAVE is open (the in-app banner does that) and opens Meldingen when a banner is tapped.
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // Shares and applications have their own notifications; the rest are meldingen, a mail opening its conversation.
        let identifier = response.notification.request.identifier
        if await FairAlerts.handle(response) { return }
        if await ShareAlerts.handle(response) { return }
        if identifier.hasPrefix("application.") {
            await MainActor.run { PaveLinkInbox.send(.applications) }
            return
        }
        let threadID = response.notification.request.content.userInfo[NotificationAlerts.emailThreadKey] as? String
        await MainActor.run { NotificationAlerts.onTap?(threadID) }
    }
}
