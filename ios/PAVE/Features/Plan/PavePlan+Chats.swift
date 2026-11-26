import Foundation
import PAVECore

extension PavePlan {
    /// The chats of the plan as the list of chats knows them, newest first: with their current title, without locked
    /// or archived chats, and, once the whole list has loaded, without chats that were deleted.
    func liveConversations(in list: AylaConversationList, isComplete: Bool) -> [PavePlanConversation] {
        let known = Dictionary(list.conversations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return conversations
            .compactMap { chat -> (PavePlanConversation, Date)? in
                guard let conversation = known[chat.id] else {
                    return isComplete ? nil : (chat, chat.addedAt)
                }
                guard !conversation.isLocked, !conversation.isArchived else { return nil }
                var shown = chat
                if !conversation.title.isEmpty { shown.title = conversation.title }
                return (shown, max(conversation.updatedAt, chat.addedAt))
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }
}
