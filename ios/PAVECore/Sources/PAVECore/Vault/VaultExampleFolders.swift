import Foundation

/// The four folders every account starts with. They are ordinary folders: you can rename, restyle or delete them, and an
/// item is in one because it was put there. The database makes them (migration 20261112120000); the app makes them for
/// an account without any folder until then.
public enum VaultExampleFolders {
    public struct Example: Sendable {
        public let name: String
        public let category: VaultCategory
        public let color: VaultFolderColor
        public let icon: VaultFolderIcon
    }

    public static let all: [Example] = [
        Example(name: "Certificaten", category: .certificates, color: .green, icon: .checkBadge),
        Example(name: "Diploma's", category: .diplomas, color: .green, icon: .academicCap),
        Example(name: "Feedback", category: .feedback, color: .green, icon: .chatBubble),
        Example(name: "Projecten", category: .projects, color: .green, icon: .wrenchScrewdriver),
    ]

    /// The folder of this kind of evidence, where a new item goes: the example folder (Projecten for a project), or a
    /// folder you named after the kind yourself (Stages, Werkervaring). Nil when you have neither.
    public static func folder(for category: VaultCategory, in folders: [VaultFolder]) -> VaultFolder? {
        let names = [all.first { $0.category == category }?.name, category.title].compactMap { $0 }
        return folders.first { folder in names.contains { $0.localizedCaseInsensitiveCompare(folder.name) == .orderedSame } }
    }
}

/// A skill Ayla proposes for evidence you are adding, with why.
public struct VaultSkillSuggestion: Equatable, Hashable, Sendable, Decodable {
    public let name: String
    public let reason: String

    public init(name: String, reason: String) {
        self.name = name
        self.reason = reason
    }
}
