import Foundation
import PAVECore
import UserNotifications

/// Notifications about your shares, on this device: someone looked (with Intrekken in the notification) and a share
/// ends tomorrow (with Verlengen). Planned again each time the shares load; without push, a look shows up the next
/// time PAVE checks.
@MainActor
enum ShareAlerts {
    static let prefix = "share."
    static let lookCategory = "share-look"
    static let endingCategory = "share-ending"
    static let revokeAction = "share-revoke"
    static let extendAction = "share-extend"
    private static let seenKey = "shareLooksSeenUntil"

    /// Set at launch: what an action in a notification does, with the share's id.
    static var onRevoke: ((String) async -> Void)?
    static var onExtend: ((String) async -> Void)?
    /// A tap on the notification itself: that share's page in Profiel.
    static var onOpen: ((String) -> Void)?

    static func registerCategories() {
        let revoke = UNNotificationAction(identifier: revokeAction, title: SharingMessages.revoke, options: [.destructive, .authenticationRequired])
        let extend = UNNotificationAction(identifier: extendAction, title: "\(SharingMessages.extend) met een week", options: [.authenticationRequired])
        let mine: Set<UNNotificationCategory> = [
            UNNotificationCategory(identifier: lookCategory, actions: [revoke], intentIdentifiers: []),
            UNNotificationCategory(identifier: endingCategory, actions: [extend, revoke], intentIdentifiers: []),
            FairAlerts.category,
        ]
        Task {
            let center = UNUserNotificationCenter.current()
            let existing = await center.notificationCategories()
            center.setNotificationCategories(existing.filter { !$0.identifier.hasPrefix("share-") }.union(mine))
        }
    }

    static func update(with shares: [ProfileShare], now: Date = .now) {
        Task {
            let center = UNUserNotificationCenter.current()
            guard await center.notificationSettings().authorizationStatus == .authorized else { return }
            // Looks since the last time: the first time only learns where things are.
            let seenUntil = UserDefaults.standard.object(forKey: seenKey) as? Date
            let newest = shares.flatMap(\.looks).map(\.date).max()
            if let seenUntil {
                for (share, look) in ShareAdvice.newLooks(in: shares, since: seenUntil).suffix(5) {
                    let content = UNMutableNotificationContent()
                    content.title = (look.action == .download ? "\(share.recipientName) downloadde je gegevens" : "\(share.recipientName) bekeek je gegevens").translated
                    content.body = share.title
                    content.categoryIdentifier = lookCategory
                    content.threadIdentifier = "shares"
                    content.userInfo = ["shareID": share.id]
                    try? await center.add(UNNotificationRequest(identifier: "\(prefix)\(share.id).look.\(look.id)", content: content, trigger: nil))
                }
            }
            if let newest, newest > (seenUntil ?? .distantPast) { UserDefaults.standard.set(newest, forKey: seenKey) }
            if seenUntil == nil { UserDefaults.standard.set(newest ?? now, forKey: seenKey) }

            // A day before the end, at the same time of day.
            let planned = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) && $0.hasSuffix(".ending") }
            center.removePendingNotificationRequests(withIdentifiers: planned)
            for share in shares where share.state(at: now) == .active {
                let at = share.expiresAt.addingTimeInterval(-86_400)
                guard at > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Delen met \(share.recipientName) stopt morgen".translated
                content.body = share.title
                content.categoryIdentifier = endingCategory
                content.threadIdentifier = "shares"
                content.userInfo = ["shareID": share.id]
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
                try? await center.add(UNNotificationRequest(identifier: "\(prefix)\(share.id).ending", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
            }
        }
    }

    /// From the notification delegate; true when it was one of ours.
    static func handle(_ response: UNNotificationResponse) async -> Bool {
        let request = response.notification.request
        guard request.identifier.hasPrefix(prefix), let shareID = request.content.userInfo["shareID"] as? String else { return false }
        switch response.actionIdentifier {
        case revokeAction: await onRevoke?(shareID)
        case extendAction: await onExtend?(shareID)
        default: await MainActor.run { onOpen?(shareID) }
        }
        return true
    }
}
