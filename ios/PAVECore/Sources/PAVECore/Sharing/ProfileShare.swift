import Foundation

/// Who a share is made for: what they minimally need differs (schetsboek p. 3), so the selection starts from that.
public enum ShareTemplate: String, Codable, CaseIterable, Sendable, Identifiable {
    case employer, education, municipality, fair

    public var id: Self { self }

    /// The kinds of evidence this recipient needs; the rest is off at the start and marked as "niet nodig".
    public var categories: Set<VaultCategory> {
        switch self {
        case .employer: [.workExperience, .internships, .projects, .certificates, .badges, .diplomas]
        case .education: [.diplomas, .certificates, .badges, .projects, .internships]
        case .municipality: [.diplomas, .certificates, .workExperience]
        case .fair: [.workExperience, .internships, .projects, .certificates, .diplomas]
        }
    }

    /// Whether the CV and letter of an application belong in it.
    public var offersApplication: Bool { self == .employer || self == .fair }

    /// How long it is shared at the start.
    public var duration: ShareDuration {
        switch self {
        case .fair: .week
        case .employer: .twoWeeks
        case .education, .municipality: .month
        }
    }
}

/// How long the recipient can look.
public enum ShareDuration: CaseIterable, Sendable, Hashable {
    case day, week, twoWeeks, month, threeMonths

    public var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .twoWeeks: 14
        case .month: 30
        case .threeMonths: 90
        }
    }

    public func end(from start: Date) -> Date { start.addingTimeInterval(TimeInterval(days) * 86_400) }
}

public enum ShareState: Equatable, Sendable {
    case active, paused, revoked, expired
}

/// What the owner shows about themselves, kept with the share.
public struct ShareProfile: Codable, Equatable, Sendable {
    public var name: String
    public var headline: String?
    public var email: String?
    public var phone: String?
    public var city: String?
    public var summary: String?
    /// The profile photo goes along: share-view signs a short-lived link to it.
    public var showsPhoto: Bool?

    public init(
        name: String, headline: String? = nil, email: String? = nil, phone: String? = nil, city: String? = nil, summary: String? = nil,
        showsPhoto: Bool? = nil
    ) {
        self.showsPhoto = showsPhoto
        self.name = name
        self.headline = headline
        self.email = email
        self.phone = phone
        self.city = city
        self.summary = summary
    }
}

/// What a share keeps besides the evidence it names: the profile, the CV and letter, and their pdfs.
public struct ShareContent: Codable, Equatable, Sendable {
    public var profile: ShareProfile
    public var cv: CVContent?
    public var letter: LetterContent?
    /// "cv" and "letter" to their path in the bucket.
    public var documents: [String: String]?
    /// The application it is part of, so it can be taken back when that ends.
    public var vacancyID: String?
    /// Evidence shown briefly on the recipient's page: no description and no skills.
    public var brief: [String]?
    /// Evidence whose files the recipient may open, with who verified it.
    public var files: [String]?
    /// Single files of that evidence the recipient may not open: the owner turned them off one by one.
    public var hiddenFiles: [String]?

    public init(
        profile: ShareProfile, cv: CVContent? = nil, letter: LetterContent? = nil, documents: [String: String]? = nil, vacancyID: String? = nil,
        brief: [String]? = nil, files: [String]? = nil, hiddenFiles: [String]? = nil
    ) {
        self.hiddenFiles = hiddenFiles
        self.profile = profile
        self.cv = cv
        self.letter = letter
        self.documents = documents
        self.vacancyID = vacancyID
        self.brief = brief
        self.files = files
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Taken back or ended, the content is wiped to {}.
        profile = (try? values.decode(ShareProfile.self, forKey: .profile)) ?? ShareProfile(name: "")
        cv = try? values.decodeIfPresent(CVContent.self, forKey: .cv)
        letter = try? values.decodeIfPresent(LetterContent.self, forKey: .letter)
        documents = try? values.decodeIfPresent([String: String].self, forKey: .documents)
        vacancyID = try? values.decodeIfPresent(String.self, forKey: .vacancyID)
        brief = try? values.decodeIfPresent([String].self, forKey: .brief)
        files = try? values.decodeIfPresent([String].self, forKey: .files)
        hiddenFiles = try? values.decodeIfPresent([String].self, forKey: .hiddenFiles)
    }
}

/// One look at a share, as `share-view` wrote it down.
public struct ShareLook: Identifiable, Equatable, Sendable {
    public enum Action: String, Sendable { case view, download }

    public let id: String
    public let date: Date
    public let action: Action
    /// What the visitor said about themselves, unchecked.
    public let viewerName: String?
    public let viewerOrganisation: String?

    public init(id: String, date: Date, action: Action, viewerName: String? = nil, viewerOrganisation: String? = nil) {
        self.id = id
        self.date = date
        self.action = action
        self.viewerName = viewerName
        self.viewerOrganisation = viewerOrganisation
    }
}

/// A selection of your data shared with someone, for a while.
public struct ProfileShare: Identifiable, Equatable, Sendable {
    public let id: String
    public let code: String
    public var title: String
    public var recipientName: String
    public var recipientOrganisation: String?
    public var purpose: String?
    public var template: ShareTemplate
    public var itemIDs: [String]
    public var content: ShareContent
    public var allowsDownload: Bool
    public var expiresAt: Date
    public var pausedAt: Date?
    public var revokedAt: Date?
    public let createdAt: Date
    /// Newest first.
    public var looks: [ShareLook]

    public init(
        id: String, code: String, title: String, recipientName: String, recipientOrganisation: String? = nil, purpose: String? = nil,
        template: ShareTemplate, itemIDs: [String] = [], content: ShareContent, allowsDownload: Bool = false, expiresAt: Date,
        pausedAt: Date? = nil, revokedAt: Date? = nil, createdAt: Date = .now, looks: [ShareLook] = []
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.recipientName = recipientName
        self.recipientOrganisation = recipientOrganisation
        self.purpose = purpose
        self.template = template
        self.itemIDs = itemIDs
        self.content = content
        self.allowsDownload = allowsDownload
        self.expiresAt = expiresAt
        self.pausedAt = pausedAt
        self.revokedAt = revokedAt
        self.createdAt = createdAt
        self.looks = looks
    }

    /// The same order of checks as `share-view`: taken back, then ended, then paused.
    public func state(at now: Date = .now) -> ShareState {
        if revokedAt != nil { return .revoked }
        if expiresAt <= now { return .expired }
        if pausedAt != nil { return .paused }
        return .active
    }

    /// Still something to manage: on or paused.
    public func isLive(at now: Date = .now) -> Bool {
        let state = state(at: now)
        return state == .active || state == .paused
    }

    /// "Sanne de Vries (Kade Consultancy)".
    public var recipient: String {
        guard let organisation = recipientOrganisation, !organisation.isEmpty else { return recipientName }
        return "\(recipientName) (\(organisation))"
    }

    public var hasApplication: Bool { content.cv != nil || content.letter != nil }
}

/// What the owner chose, to make a share from.
public struct ShareDraft: Equatable, Sendable {
    public var title: String
    public var recipientName: String
    public var recipientOrganisation: String
    public var purpose: String
    public var template: ShareTemplate
    public var itemIDs: [String]
    public var content: ShareContent
    public var allowsDownload: Bool
    public var duration: ShareDuration

    public init(
        title: String = "", recipientName: String = "", recipientOrganisation: String = "", purpose: String = "", template: ShareTemplate,
        itemIDs: [String] = [], content: ShareContent, allowsDownload: Bool = false, duration: ShareDuration? = nil
    ) {
        self.title = title
        self.recipientName = recipientName
        self.recipientOrganisation = recipientOrganisation
        self.purpose = purpose
        self.template = template
        self.itemIDs = itemIDs
        self.content = content
        self.allowsDownload = allowsDownload
        self.duration = duration ?? template.duration
    }

    public enum Problem: Equatable, Sendable { case noRecipient, nothingChosen, noTitle }

    /// What keeps it from being shared, checked as the database does.
    public var problem: Problem? {
        if recipientName.trimmingCharacters(in: .whitespaces).isEmpty { return .noRecipient }
        if title.trimmingCharacters(in: .whitespaces).isEmpty { return .noTitle }
        if itemIDs.isEmpty, content.cv == nil, content.letter == nil { return .nothingChosen }
        return nil
    }
}
