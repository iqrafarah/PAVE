import Foundation
import PAVECore
import UserNotifications

/// A notification when an employer at the fair invites you, the first time the app sees it. Seen invitations are
/// remembered on this device, so it is never announced twice.
@MainActor
enum FairAlerts {
    private static let seenKey = "fair.seenInvitations"

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
                content.body = SharingMessages.fairInvitedBody(application)
                content.sound = .default
                content.threadIdentifier = "fair"
                try? await center.add(UNNotificationRequest(identifier: "share.fair.\(application.id)", content: content, trigger: nil))
            }
        }
    }
}
