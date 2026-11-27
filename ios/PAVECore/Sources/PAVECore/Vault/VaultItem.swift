import Foundation

/// One piece of evidence in the vault: a diploma, a project, work experience and so on.
public struct VaultItem: Identifiable, Equatable, Sendable {
    /// Only trusted server code can confirm or reject an item; the app never sets this.
    public enum Status: String, CaseIterable, Sendable {
        case toVerify
        case verified
        case rejected
    }

    /// Who put the item in the vault.
    public enum Source: String, CaseIterable, Sendable {
        case user
        case organization
        case ayla
        case `import`
    }

    /// The most recent request to confirm the item, as the learner may read it back.
    public struct ValidationRequest: Equatable, Sendable {
        public enum Status: String, Sendable {
            case pending
            case verified
            case rejected
            case cancelled
        }

        public let status: Status
        public let organisationName: String
        public let requestedAt: Date
        /// The reviewer's reason; required when a request is rejected.
        public let response: String?
        /// The organisation and location it went to, by their IDs in the directory.
        public let organizationID: String?
        public let locationID: String?

        public init(
            status: Status, organisationName: String, requestedAt: Date, response: String? = nil,
            organizationID: String? = nil, locationID: String? = nil
        ) {
            self.status = status
            self.organisationName = organisationName
            self.requestedAt = requestedAt
            self.response = response
            self.organizationID = organizationID
            self.locationID = locationID
        }
    }

    public struct File: Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let mimeType: String
        public let storagePath: String
        public let role: VaultFileRole

        public init(id: String, name: String, mimeType: String, storagePath: String, role: VaultFileRole = .document) {
            self.id = id
            self.name = name
            self.mimeType = mimeType
            self.storagePath = storagePath
            self.role = role
        }
    }

    public let id: String
    /// The folders the item is in; it can be in several, or in none.
    public var folderIDs: [String]
    public var category: VaultCategory
    public var title: String
    public var description: String?
    public var organisationName: String?
    public var organisationLocation: String?
    public var startDate: VaultDay?
    public var endDate: VaultDay?
    public var issuedOn: VaultDay?
    public var isCurrent: Bool
    public var status: Status
    public var source: Source
    /// The skills the user kept; Ayla's proposals that were not accepted are left out.
    public var skills: [String]
    public var files: [File]
    /// When you allowed Ayla to read this item outside a single question; nil means she may not.
    public var aylaAllowedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    /// Its place in "Eigen volgorde", once you dragged your evidence into an order of your own.
    public var position: Int?
    /// "Archiveren": out of the vault, kept until it is put back or deleted. Not shared meanwhile.
    public var archivedAt: Date?
    public var lastRequest: ValidationRequest?
    /// The organisation in the directory this evidence comes from, when it was issued or imported by one. Set by the
    /// server, never typed: `organisationName` is what the learner typed.
    public var organizationID: String?

    public init(
        id: String,
        folderIDs: [String] = [],
        category: VaultCategory,
        title: String,
        description: String? = nil,
        organisationName: String? = nil,
        organisationLocation: String? = nil,
        startDate: VaultDay? = nil,
        endDate: VaultDay? = nil,
        issuedOn: VaultDay? = nil,
        isCurrent: Bool = false,
        status: Status = .toVerify,
        source: Source = .user,
        skills: [String] = [],
        files: [File] = [],
        aylaAllowedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        position: Int? = nil,
        lastRequest: ValidationRequest? = nil
    ) {
        self.id = id
        self.position = position
        self.folderIDs = folderIDs
        self.category = category
        self.title = title
        self.description = description
        self.organisationName = organisationName
        self.organisationLocation = organisationLocation
        self.startDate = startDate
        self.endDate = endDate
        self.issuedOn = issuedOn
        self.isCurrent = isCurrent
        self.status = status
        self.source = source
        self.skills = skills
        self.files = files
        self.aylaAllowedAt = aylaAllowedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastRequest = lastRequest
    }

    /// A request is open: shown as "In afwachting", and a new request cannot be sent until it is decided.
    public var isAwaitingReview: Bool {
        status == .toVerify && lastRequest?.status == .pending
    }

    /// Why the item was rejected, while it still is.
    public var rejectionReason: String? {
        guard status == .rejected, lastRequest?.status == .rejected,
              let reason = lastRequest?.response?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty
        else { return nil }
        return reason
    }

    /// Every item can be changed, but a confirmed one is then no longer confirmed: it has to be confirmed again.
    public var changeNeedsReconfirmation: Bool {
        status == .verified
    }

    /// "Pixelwerk, Eindhoven".
    public var place: String? {
        let parts = [organisationName, organisationLocation].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// "mrt 2025 - dec 2025", "nov 2025 - nu" or "jun 2025".
    public var period: String? {
        if let issuedOn, startDate == nil, endDate == nil { return issuedOn.monthAndYear }
        switch (startDate, isCurrent ? nil : endDate) {
        case let (start?, _) where isCurrent:
            return "\(start.monthAndYear) - nu"
        case let (start?, end?):
            return start.monthAndYear == end.monthAndYear ? start.monthAndYear : "\(start.monthAndYear) - \(end.monthAndYear)"
        case let (start?, nil):
            return "vanaf \(start.monthAndYear)"
        case let (nil, end?):
            return "tot \(end.monthAndYear)"
        case (nil, nil):
            return issuedOn?.monthAndYear
        }
    }

    /// The day the vault sorts on: when you got it, when it ended, today while it is still going, or when it started.
    public func sortDay(today: VaultDay) -> VaultDay {
        issuedOn ?? (isCurrent ? today : endDate ?? startDate) ?? VaultDay(createdAt)
    }

    /// The name of the first evidence file (not the logo or cover): its kind shows in the badge when there is no logo.
    public var firstDocumentName: String? {
        files.first { $0.role == .document }?.name
    }
}

/// A folder the user made. An item can sit in one folder and keeps its category.
public struct VaultFolder: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    /// `nil` while the database has no colour for it; the app then uses what this device remembers, or green.
    public var color: VaultFolderColor?
    public var icon: VaultFolderIcon?
    public let createdAt: Date
    /// "Vastgezet": pinned folders come first in the folder row.
    public var pinnedAt: Date?

    public var isPinned: Bool { pinnedAt != nil }

    public init(
        id: String, name: String, color: VaultFolderColor? = nil, icon: VaultFolderIcon? = nil, createdAt: Date = .now, pinnedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.createdAt = createdAt
        self.pinnedAt = pinnedAt
    }

    public static let maximumNameLength = 100
}

public struct VaultContents: Equatable, Sendable {
    /// What is in the vault; archived evidence is in `archived` instead.
    public var items: [VaultItem]
    public var folders: [VaultFolder]
    /// The archive, the most recently archived first.
    public var archived: [VaultItem]
    /// False before the migration with the archive (20261120120000).
    public var canArchive: Bool

    public init(items: [VaultItem] = [], folders: [VaultFolder] = [], archived: [VaultItem] = [], canArchive: Bool = false) {
        self.items = items
        self.folders = folders
        self.archived = archived
        self.canArchive = canArchive
    }
}
