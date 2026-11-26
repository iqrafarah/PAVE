import Foundation
import PAVECore
import UserNotifications

/// A notification when an employer at the fair invites you, the first time the app sees it. Seen invitations are
/// remembered on this device, so it is never announced twice.
@MainActor
enum FairAlerts {
    private static let seenKey = "fair.seenInvitations"
    static let categoryID = "share-fair-invitation"
    static let acceptAction = "share-fair-accept"
    static let declineAction = "share-fair-decline"
    static let applicationKey = "fairApplicationID"

    /// Set at launch: answers an invitation from the notification, also on a paired Apple Watch. True when it worked.
    static var onAnswer: ((String, Bool) async -> Bool)?

    /// Ik kom and Kan niet right in the notification. iOS shows the same buttons on the Watch, so at the fair you
    /// answer from your wrist; tapping one of them is the choice itself, nothing else is sent.
    static var category: UNNotificationCategory {
        UNNotificationCategory(
            identifier: categoryID,
            actions: [
                UNNotificationAction(identifier: acceptAction, title: SharingMessages.dayAccept, options: []),
                UNNotificationAction(identifier: declineAction, title: SharingMessages.dayDecline, options: [.destructive]),
            ],
            intentIdentifiers: []
        )
    }

    /// From the notification delegate; true when it was a fair invitation.
    static func handle(_ response: UNNotificationResponse) async -> Bool {
        let request = response.notification.request
        guard request.identifier.hasPrefix("share.fair.") else { return false }
        let id = request.content.userInfo[applicationKey] as? String
        switch response.actionIdentifier {
        case acceptAction, declineAction:
            let accepted = response.actionIdentifier == acceptAction
            if let id, let onAnswer, await onAnswer(id, accepted) { return true }
            NotificationAlerts.onTap?()
        default:
            // The invitation is in Meldingen, with every other message.
            NotificationAlerts.onTap?()
        }
        return true
    }

    static func announce(_ applications: [FairApplication]) {
        let defaults = UserDefaults.standard
        var seen = Set(defaults.stringArray(forKey: seenKey) ?? [])
        let fresh = applications.filter { $0.awaitsAnswer && !seen.contains($0.id) }
        guard !fresh.isEmpty else { return }
        seen.formUnion(fresh.map(\.id))
        defaults.set(Array(seen), forKey: seenKey)
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else { return }
            for application in fresh {
                let content = UNMutableNotificationContent()
                content.title = SharingMessages.fairInvitedTitle
                content.body = SharingMessages.fairInvitedBody(application, employer: FairDay.employerName(slug: application.employerSlug))
                content.sound = .default
                content.threadIdentifier = "fair"
                content.categoryIdentifier = categoryID
                content.userInfo = [applicationKey: application.id]
                try? await center.add(UNNotificationRequest(identifier: "share.fair.\(application.id)", content: content, trigger: nil))
            }
        }
    }
}
