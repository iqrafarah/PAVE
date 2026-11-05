import Foundation

public struct AylaConversation: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var updatedAt: Date

    public init(id: String, title: String, updatedAt: Date) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
    }
}

/// A message as it is stored. Messages from Ayla keep the whole reply, so cards come back too.
public struct AylaStoredMessage: Equatable, Sendable, Identifiable {
    public enum Role: String, Sendable {
        case user
        case ayla
    }

    public var id: String
    public var role: Role
    public var text: String
    public var reply: AylaReply?

    public init(id: String, role: Role, text: String, reply: AylaReply? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.reply = reply
    }
}
