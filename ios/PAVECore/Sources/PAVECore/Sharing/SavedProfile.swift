import Foundation

/// A profile you made once for a kind of recipient, such as "Voor werkgevers": which evidence goes in, which of it only
/// briefly, a line under your name and whether your e-mail is on it. Keeping one shares nothing; sharing it makes a
/// share as always.
public struct SavedProfile: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var template: ShareTemplate
    public var itemIDs: [String]
    /// Shown with title, organisation, period and status only; the rest also with description and skills.
    public var briefIDs: Set<String>
    public var headline: String
    public var includesEmail: Bool
    /// Evidence whose files go along, so the recipient can open the diploma itself.
    public var fileIDs: Set<String>
    /// A few sentences about you, on top of what you share.
    public var summary: String
    /// How long a share of this selection lasts; nil keeps what fits the recipient.
    public var duration: ShareDuration?
    public var updatedAt: Date

    public static let summaryLimit = 400

    public init(
        id: String = "", name: String, template: ShareTemplate, itemIDs: [String] = [], briefIDs: Set<String> = [], headline: String = "",
        includesEmail: Bool = true, fileIDs: Set<String> = [], summary: String = "", duration: ShareDuration? = nil, updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.template = template
        self.itemIDs = itemIDs
        self.briefIDs = briefIDs
        self.headline = headline
        self.includesEmail = includesEmail
        self.fileIDs = fileIDs
        self.summary = summary
        self.duration = duration
        self.updatedAt = updatedAt
    }

    public enum Problem: Equatable, Sendable { case noName, nothingChosen }

    public var problem: Problem? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return .noName }
        if itemIDs.isEmpty { return .nothingChosen }
        return nil
    }

    /// Only what is still in the profile can be brief.
    public var brief: [String] { itemIDs.filter(briefIDs.contains) }

    /// Only what is still in the selection can take its files along.
    public var files: [String] { itemIDs.filter(fileIDs.contains) }

    /// A first profile for a kind of recipient, from what that recipient usually needs.
    public static func starter(for template: ShareTemplate, items: [VaultItem]) -> SavedProfile {
        let chosen = items.filter { template.categories.contains($0.category) && $0.status != .rejected }
        return SavedProfile(name: template.profileName, template: template, itemIDs: chosen.map(\.id), fileIDs: ShareFiles.byDefault(chosen))
    }
}

extension ShareTemplate {
    /// The name a new profile for this recipient starts with.
    public var profileName: String {
        switch self {
        case .employer: "Voor werkgevers"
        case .education: "Voor school"
        case .municipality: "Voor de gemeente"
        case .fair: "Voor de banenbeurs"
        }
    }
}

/// Which evidence takes its files along when you share: every piece that has a document, unless you turn it off.
public enum ShareFiles {
    public static func hasDocument(_ item: VaultItem) -> Bool { item.files.contains { $0.role == .document } }

    public static func byDefault(_ items: [VaultItem]) -> Set<String> {
        Set(items.filter { $0.status != .rejected && hasDocument($0) }.map(\.id))
    }

    /// The files of a selection: what it says, or the default when it never chose (made before files could go along).
    public static func of(_ profile: SavedProfile, items: [VaultItem]) -> Set<String> {
        profile.fileIDs.isEmpty ? byDefault(items) : profile.fileIDs
    }
}

extension ShareDuration {
    /// From the number of days kept with a selection.
    public init?(days: Int) {
        guard let match = Self.allCases.first(where: { $0.days == days }) else { return nil }
        self = match
    }
}
