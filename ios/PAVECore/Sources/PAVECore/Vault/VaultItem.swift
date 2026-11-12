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
        updatedAt: Date = .now
    ) {
        self.id = id
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
}

/// A folder the user made. An item can sit in one folder and keeps its category.
public struct VaultFolder: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    /// `nil` while the database has no colour for it; the app then uses what this device remembers, or green.
    public var color: VaultFolderColor?
    public var icon: VaultFolderIcon?
    public let createdAt: Date

    public init(id: String, name: String, color: VaultFolderColor? = nil, icon: VaultFolderIcon? = nil, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.createdAt = createdAt
    }

    public static let maximumNameLength = 100
}

public struct VaultContents: Equatable, Sendable {
    public var items: [VaultItem]
    public var folders: [VaultFolder]

    public init(items: [VaultItem] = [], folders: [VaultFolder] = []) {
        self.items = items
        self.folders = folders
    }
}
