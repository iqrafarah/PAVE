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

    public init(conversationId: String? = nil, text: String, device: AylaDevice, input: AylaInput, context: Context? = nil) {
        self.conversationId = conversationId
        self.text = text
        self.device = device
        self.input = input
        self.context = context
    }
}
