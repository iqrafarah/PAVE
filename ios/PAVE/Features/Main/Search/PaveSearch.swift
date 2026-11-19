import Foundation
import PAVECore

/// The kinds to search in, as the tabs of "Zoeken in PAVE" on the web (AylaSearchDialog).
enum PaveSearchTab: String, CaseIterable, Identifiable {
    case all = "Alles"
    case chats = "Chats"
    case projects = "Projecten"
    case items = "Bewijzen"
    case documents = "Documenten"
    case images = "Afbeeldingen"

    var id: Self { self }
    var needsVault: Bool { self == .items || self == .documents || self == .images }
    func shows(_ kind: PaveSearchTab) -> Bool { self == .all || self == kind }

    /// The tabs that can find something: the vault ones once the vault is there, projects once they exist.
    static func available(vaultReady: Bool, projects: Bool) -> [PaveSearchTab] {
        allCases.filter { (!$0.needsVault || vaultReady) && ($0 != .projects || projects) }
    }
}

/// What the search finds besides chat titles and messages; capitals and accents do not matter ("cafe" finds "Café").
enum PaveSearch {
    /// Without search words everything matches, so a tab alone shows all of its kind.
    static func contains(_ text: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        return text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_NL")) != nil
    }

    static func projects(_ list: AylaConversationList, matching needle: String) -> [AylaProject] {
        list.orderedProjects.filter { contains($0.name, needle) || contains($0.instructions, needle) }
    }

    @MainActor
    static func items(_ vault: VaultModel?, matching needle: String) -> [VaultItem] {
        guard let vault, vault.state == .ready else { return [] }
        return Array(vault.items.filter { item in
            contains(item.title, needle) || contains(item.organisationName ?? "", needle) || item.skills.contains { contains($0, needle) }
        }.prefix(needle.isEmpty ? 100 : 20))
    }

    /// Documents and pictures in the vault whose name matches, for the tabs that show them.
    @MainActor
    static func files(_ vault: VaultModel?, matching needle: String, tab: PaveSearchTab) -> [(file: VaultItem.File, item: VaultItem)] {
        guard let vault, vault.state == .ready, tab == .all || tab == .documents || tab == .images else { return [] }
        let found = vault.items.flatMap { item in
            vault.documents(of: item).filter { contains($0.name, needle) }.map { (file: $0, item: item) }
        }
        return Array(found.filter { found in
            let isImage = VaultFileTypeIcon.Kind(fileName: found.file.name) == .image
            switch tab {
            case .documents: return !isImage
            case .images: return isImage
            default: return true
            }
        }.prefix(needle.isEmpty ? 100 : 20))
    }
}
