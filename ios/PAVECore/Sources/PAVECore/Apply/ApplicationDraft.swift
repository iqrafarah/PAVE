import Foundation

/// A CV and a motivation letter for one vacancy, made with Ayla and changed by hand. The content is kept apart from
/// how it looks, so another template never loses what was written.
public struct ApplicationDraft: Codable, Equatable, Sendable, Identifiable {
    /// The vacancy it is for; one draft per vacancy.
    public var id: String { vacancy.id }
    public var vacancy: Vacancy
    public var template: ApplicationTemplate
    /// The colour of headings and lines, as 0xRRGGBB; readable on white.
    public var accent: UInt32
    public var showsPhoto: Bool
    public var cv: CVContent
    public var letter: LetterContent
    public var updatedAt: Date

    public init(
        vacancy: Vacancy, template: ApplicationTemplate = .calm, accent: UInt32 = 0x355D4C, showsPhoto: Bool = false,
        cv: CVContent, letter: LetterContent, updatedAt: Date = .now
    ) {
        self.vacancy = vacancy
        self.template = template
        self.accent = accent
        self.showsPhoto = showsPhoto
        self.cv = cv
        self.letter = letter
        self.updatedAt = updatedAt
    }
}

/// How the CV and the letter look; both use the same one, so they belong together.
public enum ApplicationTemplate: String, Codable, CaseIterable, Sendable, Identifiable {
    /// One column, quiet and classic.
    case calm
    /// A side column with contact details and skills.
    case modern
    /// A band of colour across the top, with the photo in it.
    case bold
    /// Small and tight, so a lot fits on one page.
    case compact

    public var id: Self { self }
}

public struct CVContent: Codable, Equatable, Sendable {
    public var name: String
    /// One line under the name, such as "Student HBO-ICT".
    public var headline: String
    public var email: String
    public var phone: String
    public var city: String
    public var profile: String
    public var sections: [CVSection]
    public var skills: [String]

    public init(name: String = "", headline: String = "", email: String = "", phone: String = "", city: String = "", profile: String = "", sections: [CVSection] = [], skills: [String] = []) {
        self.name = name
        self.headline = headline
        self.email = email
        self.phone = phone
        self.city = city
        self.profile = profile
        self.sections = sections
        self.skills = skills
    }

    /// The sections that show, in their order.
    public var visibleSections: [CVSection] { sections.filter { $0.isVisible && !$0.entries.isEmpty } }
}

public struct CVSection: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case experience, education, certificates, projects
    }

    public var kind: Kind
    public var isVisible: Bool
    public var entries: [CVEntry]

    public var id: Kind { kind }

    public init(kind: Kind, isVisible: Bool = true, entries: [CVEntry]) {
        self.kind = kind
        self.isVisible = isVisible
        self.entries = entries
    }
}

/// One line of experience or education, made from a piece of evidence in the vault or typed by hand.
public struct CVEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var organisation: String
    public var period: String
    public var description: String
    public var isVisible: Bool
    /// The piece of evidence it came from; nil when typed by hand.
    public var sourceItemID: String?

    public init(id: String = UUID().uuidString, title: String, organisation: String = "", period: String = "", description: String = "", isVisible: Bool = true, sourceItemID: String? = nil) {
        self.id = id
        self.title = title
        self.organisation = organisation
        self.period = period
        self.description = description
        self.isVisible = isVisible
        self.sourceItemID = sourceItemID
    }
}

public struct LetterContent: Codable, Equatable, Sendable {
    public var salutation: String
    public var paragraphs: [LetterParagraph]
    public var closing: String
    public var signature: String

    public init(salutation: String = "", paragraphs: [LetterParagraph] = [], closing: String = "", signature: String = "") {
        self.salutation = salutation
        self.paragraphs = paragraphs
        self.closing = closing
        self.signature = signature
    }
}

public struct LetterParagraph: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    /// The evidence this paragraph is about, so what it claims can be checked.
    public var sourceItemIDs: [String]

    public init(id: String = UUID().uuidString, text: String, sourceItemIDs: [String] = []) {
        self.id = id
        self.text = text
        self.sourceItemIDs = sourceItemIDs
    }
}
