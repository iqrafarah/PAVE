import Foundation

/// "Projecten": a folder for chats with instructions of your own for Ayla, as on the web (`ayla_projects`, migration
/// 20261118120000). Ayla follows the instructions in every chat of the project, as long as they do not go against her
/// own rules. Deleting a project keeps its chats.
public struct AylaProject: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var instructions: String
    public var updatedAt: Date
    public var pinnedAt: Date?

    public var isPinned: Bool { pinnedAt != nil }

    public init(id: String, name: String, instructions: String = "", updatedAt: Date = .now, pinnedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.updatedAt = updatedAt
        self.pinnedAt = pinnedAt
    }

    public static let maxNameLength = 80
    public static let maxInstructionsLength = 2000

    /// A name someone typed, tidied up; nil when nothing is left.
    public static func cleanName(_ text: String) -> String? {
        let words = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !words.isEmpty else { return nil }
        return String(words.prefix(maxNameLength))
    }
}

/// Why a PIN for the locked chats was not accepted. The PIN is only checked in the database (hashed, with a wait of
/// five minutes after five wrong tries); the app never stores it.
public enum AylaChatPinError: Error, Equatable, Sendable {
    case wrong
    case tooManyAttempts
    case noPin
    case alreadySet
}
