import Foundation

/// What Ayla is asked to write for a CV or a letter (the `ayla-document` function). Only evidence she may see goes
/// along; the caller picks it.
public struct ApplicationWritingRequest: Encodable, Equatable, Sendable {
    public enum Kind: String, Encodable, Sendable {
        case profile, letter, rewrite
    }

    /// Ways to write one block again.
    public enum Rewrite: String, Encodable, CaseIterable, Sendable {
        case shorter, stronger, english, formal, personal
    }

    public enum Tone: String, Encodable, Sendable {
        case formal, personal
    }

    public struct Item: Encodable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var category: String
        public var organisation: String?
        public var period: String?
        public var description: String?
        public var skills: [String]

        public init(_ item: VaultItem) {
            id = item.id
            title = item.title
            category = item.category.rawValue
            organisation = item.organisationName
            period = item.period
            description = item.description.map { String($0.prefix(600)) }
            skills = Array(item.skills.prefix(10))
        }
    }

    public var kind: Kind
    public var vacancy: AylaRequest.OpenVacancy
    public var name: String
    public var items: [Item]
    public var text: String?
    public var rewrite: Rewrite?
    public var tone: Tone

    /// At most this many pieces of evidence go along.
    public static let maximumItems = 20

    public init(kind: Kind, vacancy: Vacancy, name: String, items: [VaultItem], text: String? = nil, rewrite: Rewrite? = nil, tone: Tone = .personal) {
        self.kind = kind
        self.vacancy = AylaRequest.OpenVacancy(vacancy)
        self.name = name
        self.items = items.prefix(Self.maximumItems).map(Item.init)
        self.text = text
        self.rewrite = rewrite
        self.tone = tone
    }
}

/// What Ayla wrote; only the fields of the kind that was asked are filled.
public struct ApplicationWriting: Decodable, Equatable, Sendable {
    public struct Paragraph: Decodable, Equatable, Sendable {
        public var text: String
        public var sourceItemIDs: [String]

        public init(text: String, sourceItemIDs: [String] = []) {
            self.text = text
            self.sourceItemIDs = sourceItemIDs
        }
    }

    public var profile: String?
    public var salutation: String?
    public var paragraphs: [Paragraph]?
    public var closing: String?
    public var text: String?

    public init(profile: String? = nil, salutation: String? = nil, paragraphs: [Paragraph]? = nil, closing: String? = nil, text: String? = nil) {
        self.profile = profile
        self.salutation = salutation
        self.paragraphs = paragraphs
        self.closing = closing
        self.text = text
    }
}
