import Foundation

/// A CV and a motivation letter for one vacancy, made with Ayla and changed by hand. The content is kept apart from
/// how it looks, so another template never loses what was written.
public struct ApplicationDraft: Codable, Equatable, Sendable, Identifiable {
    /// The vacancy it is for; one draft per vacancy.
    public var id: String { vacancy.id }
    public var vacancy: Vacancy
    public var template: ApplicationTemplate
    public var palette: ApplicationPalette
    public var showsPhoto: Bool
    public var cv: CVContent
    public var letter: LetterContent
    /// What the user wants Ayla to stress in the profile and the letter, in their own words; nil when nothing.
    public var focus: String?
    /// A tick on the CV at evidence that is verified; on unless the user turned it off.
    public var showsVerified: Bool?
    /// Status, deadline and note of the application; nil until the user sets one.
    public var tracking: ApplicationTracking?
    /// Reports of practice interviews for this vacancy, the newest last.
    public var practice: [PracticeReport]?
    public var updatedAt: Date

    /// The tracking, or a new one.
    public var progress: ApplicationTracking { tracking ?? ApplicationTracking() }

    /// Whether verified evidence is marked on the CV.
    public var marksVerified: Bool { showsVerified ?? true }

    public init(
        vacancy: Vacancy, template: ApplicationTemplate = .sage, palette: ApplicationPalette? = nil, showsPhoto: Bool = true,
        cv: CVContent, letter: LetterContent, focus: String? = nil, updatedAt: Date = .now
    ) {
        self.vacancy = vacancy
        self.template = template
        self.palette = palette ?? template.palette
        self.showsPhoto = showsPhoto
        self.cv = cv
        self.letter = letter
        self.focus = focus
        self.updatedAt = updatedAt
    }
}

/// How the CV and the letter look; both use the same one, so they belong together. Each has its own character, as
/// the designs in Canva do; the colours come from the palette.
/// The designs, from plain to rich: the gallery shows them in this order.
public enum ApplicationTemplate: String, Codable, CaseIterable, Sendable, Identifiable {
    /// One column, plain titles, no photo: what every application system reads without trouble.
    case plain
    /// Minimal: lots of white, a serif name, thin lines.
    case frame
    /// A timeline down the page, dates in monospace.
    case line
    /// Elegant: a soft side column with the photo, serif headings.
    case sage
    /// Business: a dark side column, the photo in a rounded square.
    case night
    /// Modern: a band of colour with the name across the top, two columns below.
    case column
    /// Every part on its own tile, as in a bento grid.
    case block
    /// Creative: large circles of colour behind the photo, rounded type.
    case coral
    /// The photo in the middle of rings, everything centred under it.
    case halo
    /// A slanted band with the name, figures that stand out, two columns.
    case tilt

    public var id: Self { self }

    /// The palette it starts with.
    public var palette: ApplicationPalette {
        switch self {
        case .plain: .ocean
        case .frame: .mono
        case .line: .pave
        case .sage: .sage
        case .night: .night
        case .column: .teal
        case .block: .lavender
        case .coral: .coral
        case .halo: .rose
        case .tilt: .teal
        }
    }

    /// Made for a photo; the others leave it out or keep it small.
    public var hasPhoto: Bool { ![.plain, .frame, .line].contains(self) }

    public enum Style: String, CaseIterable, Sendable {
        case business, creative, minimal, elegant
    }

    public var styles: Set<Style> {
        switch self {
        case .plain: [.business, .minimal]
        case .frame: [.minimal, .elegant]
        case .line: [.minimal]
        case .sage: [.elegant]
        case .night: [.business]
        case .column: [.business, .creative]
        case .block: [.creative, .business]
        case .coral: [.creative]
        case .halo: [.creative, .elegant]
        case .tilt: [.creative]
        }
    }

    public init(from decoder: any Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .sage
    }
}

/// The colours of a design, as 0xRRGGBB: the accent, a soft tint of it for surfaces, and a dark tone for blocks
/// with white text. Every accent is readable on white.
public enum ApplicationPalette: String, Codable, CaseIterable, Sendable, Identifiable {
    case pave, sage, ocean, teal, night, coral, rose, lavender, mono

    public var id: Self { self }

    public var accent: UInt32 {
        switch self {
        case .rose: 0xB0466B
        case .teal: 0x1F7A78
        case .pave: 0x355D4C
        case .sage: 0x4F7A64
        case .ocean: 0x2F6DB5
        case .night: 0xB7791F
        case .coral: 0xC9553E
        case .lavender: 0x6B55B8
        case .mono: 0x2B2B2B
        }
    }

    public var tint: UInt32 {
        switch self {
        case .rose: 0xF8E8EE
        case .teal: 0xE2F1F0
        case .pave: 0xE6EEEA
        case .sage: 0xE9F0EB
        case .ocean: 0xE7EFF9
        case .night: 0xF5EFE2
        case .coral: 0xFBEAE5
        case .lavender: 0xEFEBFA
        case .mono: 0xF0F0F0
        }
    }

    public var dark: UInt32 {
        switch self {
        case .rose: 0x37202A
        case .teal: 0x12302F
        case .pave: 0x1F332A
        case .sage: 0x243A2F
        case .ocean: 0x17294A
        case .night: 0x1D2735
        case .coral: 0x3D2420
        case .lavender: 0x2A2348
        case .mono: 0x161616
        }
    }

    public init(from decoder: any Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .pave
    }
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
    /// The evidence is verified and the entry still says what the evidence says. Worked out again from the vault
    /// every time the draft is opened or changed (`ApplicationVerification`), never taken on trust from the file.
    public var isVerified = false

    private enum CodingKeys: String, CodingKey {
        case id, title, organisation, period, description, isVisible, sourceItemID
    }

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
