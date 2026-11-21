import Foundation

public struct AylaRequest: Codable, Equatable, Sendable {
    public struct Context: Codable, Equatable, Sendable {
        public var screen: AylaScreen
        public var itemId: String?
        /// Several items chosen from the vault for the whole conversation.
        public var itemIds: [String]?
        /// The vacancy you have open, so "past deze bij mij?" is about that one.
        public var vacancy: OpenVacancy?

        public init(screen: AylaScreen, itemId: String? = nil, itemIds: [String]? = nil, vacancy: OpenVacancy? = nil) {
            self.screen = screen
            self.itemId = itemId
            self.itemIds = itemIds
            self.vacancy = vacancy
        }
    }

    /// A vacancy as its card shows it, within the limits the server accepts.
    public struct OpenVacancy: Codable, Equatable, Sendable {
        public var title: String
        public var company: String
        public var city: String?
        public var summary: String?
        public var matches: [String]
        public var skillGap: [String]

        public init(_ vacancy: Vacancy) {
            func cut(_ text: String, _ max: Int) -> String { String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(max)) }
            func skills(_ links: [Vacancy.RequirementLink]) -> [String] {
                links.map { cut($0.skill, 120) }.filter { !$0.isEmpty }.prefix(8).map(\.self)
            }
            title = cut(vacancy.title, 200)
            company = cut(vacancy.company, 200)
            city = vacancy.city.map { cut($0, 200) }.flatMap { $0.isEmpty ? nil : $0 }
            summary = vacancy.summary.map { cut($0, 600) }.flatMap { $0.isEmpty ? nil : $0 }
            matches = skills(vacancy.matches)
            skillGap = skills(vacancy.skillGap)
        }
    }

    public var conversationId: String?
    /// Starts a new conversation inside this project; ignored when `conversationId` is given.
    public var projectId: String?
    public var text: String
    public var device: AylaDevice
    public var input: AylaInput
    public var context: Context?
    public var attachments: [AylaAttachment]?
    /// How the app is set right now, so Ayla can say how something stands and does not do what is already so.
    public var app: AppState?
    /// What came of the actions of Ayla's previous answer. The app sends this itself, so she can go on; it is not
    /// something you said, and no message of yours is stored for it.
    public var results: [ActionResult]?

    public struct ActionResult: Codable, Equatable, Sendable {
        public var kind: String
        public var ok: Bool
        public var said: String?

        private enum CodingKeys: String, CodingKey {
            case kind = "do"
            case ok, said
        }

        public init(_ kind: String, ok: Bool, said: String? = nil) {
            self.kind = kind
            self.ok = ok
            // The server takes at most 300 characters.
            self.said = said.map { String($0.prefix(300)) }
        }
    }

    /// Settings and the open conversation as the app has them. No vault content, no names of folders or evidence.
    public struct AppState: Codable, Equatable, Sendable {
        public var theme: String?
        public var textSize: String?
        public var displayMode: String?
        public var vaultLayout: String?
        public var voiceText: Bool?
        public var animations: Bool?
        public var memory: Bool?
        public var chatTitle: String?
        public var chatPinned: Bool?

        public init(
            theme: String? = nil, textSize: String? = nil, displayMode: String? = nil, vaultLayout: String? = nil,
            voiceText: Bool? = nil, animations: Bool? = nil, memory: Bool? = nil, chatTitle: String? = nil, chatPinned: Bool? = nil
        ) {
            self.theme = theme
            self.textSize = textSize
            self.displayMode = displayMode
            self.vaultLayout = vaultLayout
            self.voiceText = voiceText
            self.animations = animations
            self.memory = memory
            // The server takes at most 80 characters.
            self.chatTitle = chatTitle.map { String($0.prefix(80)) }
            self.chatPinned = chatPinned
        }
    }

    public init(
        conversationId: String? = nil,
        text: String,
        device: AylaDevice,
        input: AylaInput,
        context: Context? = nil,
        attachments: [AylaAttachment] = [],
        projectId: String? = nil,
        app: AppState? = nil,
        results: [ActionResult]? = nil
    ) {
        self.conversationId = conversationId
        self.projectId = conversationId == nil ? projectId : nil
        self.text = text
        self.device = device
        self.input = input
        self.context = context
        self.attachments = attachments.isEmpty ? nil : attachments
        self.app = app
        self.results = results?.isEmpty == false ? results.map { Array($0.prefix(8)) } : nil
    }
}

/// A file the user added to a message. The app reads its text on the device and sends only that text;
/// Ayla sees it in that one message and it is not stored.
public struct AylaAttachment: Codable, Equatable, Sendable, Identifiable {
    public static let maxCount = 5
    public static let maxTextLength = 20_000
    public static let maxNameLength = 200
    /// What Ayla gets for a photo without readable text, such as a photo of a workplace: she then asks what is on it.
    public static let photoWithoutText = "(foto zonder leesbare tekst)"

    public var id: String { name }
    public var name: String
    public var text: String
    /// For a photo: a small JPEG (base64) so Ayla can look at it. Sent with that one message, not stored.
    public var image: String?

    /// Cleans up the text and keeps it within what Ayla accepts. Nil when there is no text at all.
    public init?(name: String, text: String, image: String? = nil) {
        let cleaned = text
            .split(whereSeparator: \.isNewline)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !cleaned.isEmpty else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = String((trimmedName.isEmpty ? "Bestand" : trimmedName).prefix(Self.maxNameLength))
        self.text = String(cleaned.prefix(Self.maxTextLength))
        self.image = image
    }
}
