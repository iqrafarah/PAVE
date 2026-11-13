import Foundation

/// One document as "Laat Ayla invullen" sends it: the text the app read, or a small photo when there is no text.
public struct VaultEvidenceDocument: Equatable, Sendable {
    public let name: String
    public let text: String?
    /// A JPEG of an image file or of the first page of a PDF. Ayla's boxes point into this image.
    public let image: Data?

    public init(name: String, text: String? = nil, image: Data? = nil) {
        self.name = name
        self.text = text
        self.image = image
    }
}

/// What Ayla proposes after reading the documents ("Laat Ayla invullen", the `ayla-evidence` function). She fills in
/// only what the documents say; the user checks everything before it is saved.
public struct VaultEvidenceProposal: Equatable, Sendable, Decodable {
    /// A logo from the organisation's website, when the documents have none.
    /// A part of a document's image, as fractions of its size from the top left corner, such as the logo on a certificate.
    public struct Box: Equatable, Sendable, Decodable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    public struct Logo: Equatable, Sendable, Decodable {
        public let data: String
        public let mimeType: String
        /// The website it came from, such as "coolblue.nl".
        public let source: String

        public init(data: String, mimeType: String, source: String) {
            self.data = data
            self.mimeType = mimeType
            self.source = source
        }
    }

    public var category: VaultCategory
    public var title: String
    public var organisationName: String?
    public var organisationLocation: String?
    public var startDate: VaultDay?
    public var endDate: VaultDay?
    public var issuedOn: VaultDay?
    public var isCurrent: Bool
    public var description: String?
    public var skills: [VaultSkillSuggestion]
    /// One of the user's folders, by name.
    public var folder: String?
    /// The documents that belong to this item, as indexes in the order they were sent.
    public var documents: [Int]
    public var coverDocument: Int?
    /// The photo within the cover document's image; without it the whole image is the photo.
    public var coverBox: Box?
    public var logoDocument: Int?
    /// The logo within the logo document's image; without it the whole image is the logo.
    public var logoBox: Box?
    public var website: String?
    /// Where a field was found, such as "pagina 1", by field: title, organisation, period, description.
    public var sources: [String: String]
    public var logo: Logo?

    public init(
        category: VaultCategory, title: String, organisationName: String? = nil, organisationLocation: String? = nil,
        startDate: VaultDay? = nil, endDate: VaultDay? = nil, issuedOn: VaultDay? = nil, isCurrent: Bool = false,
        description: String? = nil, skills: [VaultSkillSuggestion] = [], folder: String? = nil, documents: [Int] = [],
        coverDocument: Int? = nil, coverBox: Box? = nil, logoDocument: Int? = nil, logoBox: Box? = nil, website: String? = nil,
        sources: [String: String] = [:], logo: Logo? = nil
    ) {
        self.category = category
        self.title = title
        self.organisationName = organisationName
        self.organisationLocation = organisationLocation
        self.startDate = startDate
        self.endDate = endDate
        self.issuedOn = issuedOn
        self.isCurrent = isCurrent
        self.description = description
        self.skills = skills
        self.folder = folder
        self.documents = documents
        self.coverDocument = coverDocument
        self.coverBox = coverBox
        self.logoDocument = logoDocument
        self.logoBox = logoBox
        self.website = website
        self.sources = sources
        self.logo = logo
    }

    private enum CodingKeys: String, CodingKey {
        case category, title, organisationName, organisationLocation, startDate, endDate, issuedOn, isCurrent
        case description, skills, folder, documents, coverDocument, coverBox, logoDocument, logoBox, website, sources, logo
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let category = try container.decodeIfPresent(String.self, forKey: .category)
        let day = { (key: CodingKeys) in try container.decodeIfPresent(String.self, forKey: key).flatMap(VaultDay.init) }
        self.init(
            category: category.flatMap(VaultCategory.init(rawValue:)) ?? .other,
            title: try container.decode(String.self, forKey: .title),
            organisationName: try container.decodeIfPresent(String.self, forKey: .organisationName),
            organisationLocation: try container.decodeIfPresent(String.self, forKey: .organisationLocation),
            startDate: try day(.startDate),
            endDate: try day(.endDate),
            issuedOn: try day(.issuedOn),
            isCurrent: try container.decodeIfPresent(Bool.self, forKey: .isCurrent) ?? false,
            description: try container.decodeIfPresent(String.self, forKey: .description),
            skills: try container.decodeIfPresent([VaultSkillSuggestion].self, forKey: .skills) ?? [],
            folder: try container.decodeIfPresent(String.self, forKey: .folder),
            documents: try container.decodeIfPresent([Int].self, forKey: .documents) ?? [],
            coverDocument: try container.decodeIfPresent(Int.self, forKey: .coverDocument),
            coverBox: try? container.decodeIfPresent(Box.self, forKey: .coverBox),
            logoDocument: try container.decodeIfPresent(Int.self, forKey: .logoDocument),
            logoBox: try? container.decodeIfPresent(Box.self, forKey: .logoBox),
            website: try container.decodeIfPresent(String.self, forKey: .website),
            sources: try container.decodeIfPresent([String: String].self, forKey: .sources) ?? [:],
            logo: try container.decodeIfPresent(Logo.self, forKey: .logo)
        )
    }

    /// The draft with what Ayla found; the folders stay as they are, and what she did not find stays empty.
    public func applied(to draft: VaultItemDraft) -> VaultItemDraft {
        var result = draft
        result.category = category
        result.title = String(title.prefix(VaultItemDraft.maximumTitleLength))
        result.organisationName = organisationName ?? ""
        result.organisationLocation = organisationLocation ?? ""
        result.description = String((description ?? "").prefix(VaultItemDraft.maximumDescriptionLength))
        result.startDate = nil
        result.endDate = nil
        result.issuedOn = nil
        result.isCurrent = false
        if let startDate {
            result.usesPeriod = true
            result.startDate = startDate
            result.isCurrent = isCurrent
            result.endDate = isCurrent ? nil : endDate
        } else if let issuedOn {
            result.usesPeriod = false
            result.issuedOn = issuedOn
        } else {
            result.usesPeriod = nil
        }
        return result
    }

    /// The fields Ayla filled in, so the form can say so.
    public var filledFields: [VaultItemDraft.Field] {
        VaultItemDraft.Field.allCases.filter { field in
            switch field {
            case .title: !title.isEmpty
            case .organisation: organisationName != nil
            case .period: startDate != nil || issuedOn != nil
            case .description: description != nil
            }
        }
    }

    /// Where Ayla found a field, such as "pagina 1".
    public func source(of field: VaultItemDraft.Field) -> String? {
        let key = switch field {
        case .title: "title"
        case .organisation: "organisation"
        case .period: "period"
        case .description: "description"
        }
        return sources[key]
    }
}
