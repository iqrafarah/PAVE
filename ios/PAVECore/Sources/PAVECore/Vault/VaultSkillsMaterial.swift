import Foundation

/// What Ayla looks at for her skill proposal besides the form: the text the app read from the documents and small JPEG
/// photos of image files and scanned pages. Only sent when she is asked, and nothing of it is stored.
public struct VaultSkillsMaterial: Equatable, Sendable {
    public struct Text: Equatable, Sendable {
        public let name: String
        public let text: String

        public init(name: String, text: String) {
            self.name = name
            self.text = text
        }
    }

    public struct Image: Equatable, Sendable {
        public let name: String
        public let jpeg: Data

        public init(name: String, jpeg: Data) {
            self.name = name
            self.jpeg = jpeg
        }
    }

    public static let maximumTextLength = 6000
    public static let maximumImages = 4

    public var texts: [Text]
    public var images: [Image]

    public init(texts: [Text] = [], images: [Image] = []) {
        self.texts = texts
        self.images = images
    }

    /// How many files Ayla looked at.
    public var fileCount: Int { texts.count + images.count }
}
