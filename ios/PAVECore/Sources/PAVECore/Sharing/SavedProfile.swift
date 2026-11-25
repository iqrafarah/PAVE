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
    public var updatedAt: Date

    public init(id: String = "", name: String, template: ShareTemplate, itemIDs: [String] = [], briefIDs: Set<String> = [], headline: String = "", includesEmail: Bool = true, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.template = template
        self.itemIDs = itemIDs
        self.briefIDs = briefIDs
        self.headline = headline
        self.includesEmail = includesEmail
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

    /// A first profile for a kind of recipient, from what that recipient usually needs.
    public static func starter(for template: ShareTemplate, items: [VaultItem]) -> SavedProfile {
        let chosen = items.filter { template.categories.contains($0.category) && $0.status != .rejected }.map(\.id)
        return SavedProfile(name: template.profileName, template: template, itemIDs: chosen)
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
