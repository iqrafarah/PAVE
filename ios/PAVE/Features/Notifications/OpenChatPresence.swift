import SwiftUI

extension View {
    /// The chat on screen: a melding about it shows no banner, and Ayla's answers in it make no melding at all.
    /// Nil when no chat is on screen, such as on another page or with PAVE in the background.
    func keepsOpenChat(_ conversationID: String?, in notifications: NotificationsModel) -> some View {
        onChange(of: conversationID, initial: true) { _, id in
            notifications.openConversationID = id
        }
        .task(id: conversationID) {
            guard let conversationID else { return }
            await notifications.keepOpen(conversationID)
        }
    }
}
