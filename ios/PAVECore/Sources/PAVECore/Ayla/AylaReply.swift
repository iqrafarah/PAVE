import Foundation

/// A reply from Ayla. Mirrors `shared/ayla/reply.schema.json`.
public struct AylaReply: Codable, Equatable, Sendable {
    public static let version = 1

    public struct Choice: Codable, Equatable, Sendable {
        public var id: String
        public var label: String

        public init(id: String, label: String) {
            self.id = id
            self.label = label
        }
    }

    public struct Question: Codable, Equatable, Sendable {
        public var text: String
        public var choices: [Choice]

        public init(text: String, choices: [Choice]) {
            self.text = text
            self.choices = choices
        }
    }

    /// Ayla asks to use parts of the vault for one task. Nothing is used before the user grants it.
    public struct AccessRequest: Codable, Equatable, Sendable {
        public var id: String
        public var purpose: String
        public var categories: [AylaVaultCategory]

        public init(id: String, purpose: String, categories: [AylaVaultCategory]) {
            self.id = id
            self.purpose = purpose
            self.categories = categories
        }
    }

    /// A change Ayla suggests. It only happens after the user confirms it.
    public struct ProposedAction: Codable, Equatable, Sendable {
        public var id: String
        public var kind: AylaActionKind
        public var summary: String
        public var expiresAt: Date

        public init(id: String, kind: AylaActionKind, summary: String, expiresAt: Date) {
            self.id = id
            self.kind = kind
            self.summary = summary
            self.expiresAt = expiresAt
        }
    }

    public struct Navigation: Codable, Equatable, Sendable {
        public var screen: AylaScreen
        public var itemId: String?

        public init(screen: AylaScreen, itemId: String? = nil) {
            self.screen = screen
            self.itemId = itemId
        }
    }

    public var version: Int
    public var id: String
    public var conversationId: String
    public var text: String
    public var question: Question?
    public var accessRequest: AccessRequest?
    public var proposedAction: ProposedAction?
    public var blocks: [AylaBlock]
    public var navigation: Navigation?
    /// Ayla suggests remembering these facts, one per item; they are saved only after the user confirms (`AylaMemory`).
    public var memories: [MemorySuggestion]?
    /// One suggestion, as the first version of the Ayla function sent it. Still read for older messages.
    public var memory: MemorySuggestion?
    /// The notes about the user this answer leans on ("Gebaseerd op").
    public var usedMemories: [UsedMemory]?

    public struct UsedMemory: Codable, Equatable, Hashable, Sendable {
        public var text: String
        public var category: AylaMemory.Category

        public init(text: String, category: AylaMemory.Category) {
            self.text = text
            self.category = category
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = try container.decode(String.self, forKey: .text)
            category = (try? container.decode(AylaMemory.Category.self, forKey: .category)) ?? .personal
        }
    }
    public var usedData: [AylaVaultCategory]

    /// A new fact to remember (`text`), and/or one of the user's notes it makes out of date (`replaces`, that note's
    /// exact text). An empty `text` with `replaces` only suggests taking the old note away.
    public struct MemorySuggestion: Codable, Equatable, Hashable, Sendable {
        public var text: String
        public var category: AylaMemory.Category
        public var replaces: String?

        public init(text: String, category: AylaMemory.Category = .personal, replaces: String? = nil) {
            self.text = text
            self.category = category
            self.replaces = replaces
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = (try? container.decode(String.self, forKey: .text)) ?? ""
            category = (try? container.decode(AylaMemory.Category.self, forKey: .category)) ?? .personal
            replaces = try? container.decodeIfPresent(String.self, forKey: .replaces)
        }
    }

    /// Everything Ayla suggests remembering or taking away in this reply.
    public var suggestedMemories: [MemorySuggestion] {
        (memories ?? memory.map { [$0] } ?? []).filter { !$0.text.isEmpty || $0.replaces != nil }
    }

    public init(
        id: String,
        conversationId: String,
        text: String,
        question: Question? = nil,
        accessRequest: AccessRequest? = nil,
        proposedAction: ProposedAction? = nil,
        blocks: [AylaBlock] = [],
        navigation: Navigation? = nil,
        memories: [MemorySuggestion]? = nil,
        memory: MemorySuggestion? = nil,
        usedMemories: [UsedMemory]? = nil,
        usedData: [AylaVaultCategory] = []
    ) {
        self.version = Self.version
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.question = question
        self.accessRequest = accessRequest
        self.proposedAction = proposedAction
        self.blocks = blocks
        self.navigation = navigation
        self.memories = memories
        self.memory = memory
        self.usedMemories = usedMemories
        self.usedData = usedData
    }
}

extension AylaReply {
    public static func decode(_ data: Data) throws -> AylaReply {
        try AylaCoding.decoder.decode(AylaReply.self, from: data)
    }

    public func encoded() throws -> Data {
        try AylaCoding.encoder.encode(self)
    }
}

enum AylaCoding {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
