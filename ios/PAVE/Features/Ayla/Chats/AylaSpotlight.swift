import CoreSpotlight
import PAVECore

/// Puts the titles of your chats with Ayla in the iPhone's own search, only when you switch it on in Settings.
/// Only titles, never what is in a chat. Switching it off, or signing out, takes them out again at once.
/// Handoff: the chat you have open on one device shows on your others (the PAVE icon in the Dock or the app
/// switcher), to continue right there. Only the conversation's id travels; the other device loads it with your
/// account, behind its own PIN.
enum AylaHandoff {
    static let activityType = "nl.fontys.pave.conversation"
    static let idKey = "conversationID"

    static func conversationID(in activity: NSUserActivity) -> String? {
        activity.userInfo?[idKey] as? String
    }
}

enum AylaSpotlight {
    /// Off unless someone switches it on: chat titles can say something personal.
    static let settingKey = "chatsInSpotlight"
    private static let domain = "nl.fontys.pave.ayla-chats"

    static func update(_ list: AylaConversationList) {
        let items = list.conversations.map { conversation in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = conversation.title
            attributes.contentDescription = "Chat met Ayla in PAVE"
            attributes.contentModificationDate = conversation.updatedAt
            attributes.keywords = ["Ayla", "PAVE", "chat"]
            return CSSearchableItem(uniqueIdentifier: conversation.id, domainIdentifier: domain, attributeSet: attributes)
        }
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            index.indexSearchableItems(items)
        }
    }

    static func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain])
    }

    /// When signing out: the next person on this phone starts with it switched off.
    static func forget(in defaults: UserDefaults) {
        defaults.set(false, forKey: settingKey)
        removeAll()
    }

    /// The chat a search result stands for, when someone taps it in the iPhone's search.
    static func conversationID(in activity: NSUserActivity) -> String? {
        guard activity.activityType == CSSearchableItemActionType else { return nil }
        return activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
    }
}
