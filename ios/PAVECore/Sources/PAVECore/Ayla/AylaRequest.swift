import Foundation

public struct AylaRequest: Codable, Equatable, Sendable {
    public struct Context: Codable, Equatable, Sendable {
        public var screen: AylaScreen
        public var itemId: String?

        public init(screen: AylaScreen, itemId: String? = nil) {
            self.screen = screen
            self.itemId = itemId
        }
    }

    public var conversationId: String?
    public var text: String
    public var device: AylaDevice
    public var input: AylaInput
    public var context: Context?
    public var attachments: [AylaAttachment]?

    public init(
        conversationId: String? = nil,
        text: String,
        device: AylaDevice,
        input: AylaInput,
        context: Context? = nil,
        attachments: [AylaAttachment] = []
    ) {
        self.conversationId = conversationId
        self.text = text
        self.device = device
        self.input = input
        self.context = context
        self.attachments = attachments.isEmpty ? nil : attachments
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
