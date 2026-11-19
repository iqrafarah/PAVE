import Foundation

/// How long chats stay ("Verval", as in WhatsApp). Deleting is final, so nothing expires unless the account chose it.
public struct ChatExpiry: Equatable, Sendable {
    /// From when the time runs.
    public enum Start: String, CaseIterable, Identifiable, Sendable {
        case lastMessage = "last_message"
        case created

        public var id: Self { self }
    }

    /// The periods to choose from, in days.
    public static let periods = [1, 7, 30, 90]

    /// After how many days a chat is deleted; nil is no expiry.
    public var days: Int?
    public var start: Start
    /// Pinned and locked chats stay, unless the account turned that off.
    public var keepsPinned: Bool
    public var keepsLocked: Bool

    public init(days: Int? = nil, start: Start = .lastMessage, keepsPinned: Bool = true, keepsLocked: Bool = true) {
        self.days = days
        self.start = start
        self.keepsPinned = keepsPinned
        self.keepsLocked = keepsLocked
    }

    /// When this chat is deleted, or nil when it stays. The same rules as `ayla_delete_expired_chats` in Supabase:
    /// a chat in the archive or in a project never expires, and an own choice for the chat wins over the account's.
    public func expiresAt(_ chat: AylaConversation) -> Date? {
        guard !chat.isArchived, chat.projectID == nil else { return nil }
        guard let days = chat.expiry.days(or: days), days > 0 else { return nil }
        if chat.isPinned, keepsPinned { return nil }
        if chat.isLocked, keepsLocked { return nil }
        let from = start == .created ? (chat.createdAt ?? chat.updatedAt) : chat.updatedAt
        return from.addingTimeInterval(TimeInterval(days) * 86_400)
    }
}

/// What the account chose about keeping its data.
public struct PaveRetention: Equatable, Sendable {
    public var chatExpiry: ChatExpiry
    /// Whether Ayla may use archived evidence she was allowed to see. Off unless the account turns it on.
    public var aylaUsesArchive: Bool

    public init(chatExpiry: ChatExpiry = ChatExpiry(), aylaUsesArchive: Bool = false) {
        self.chatExpiry = chatExpiry
        self.aylaUsesArchive = aylaUsesArchive
    }
}
