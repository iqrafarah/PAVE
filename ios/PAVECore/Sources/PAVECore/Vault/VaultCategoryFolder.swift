import Foundation

/// How one category folder at the top of the vault looks for you: its own name, colour and icon, or hidden.
/// The folder still shows every item of its category; nothing here changes the items.
public struct VaultCategoryFolder: Equatable, Sendable {
    public let category: VaultCategory
    public var name: String?
    public var color: VaultFolderColor?
    public var icon: VaultFolderIcon?
    public var isHidden: Bool

    public init(category: VaultCategory, name: String? = nil, color: VaultFolderColor? = nil, icon: VaultFolderIcon? = nil, isHidden: Bool = false) {
        self.category = category
        self.name = name
        self.color = color
        self.icon = icon
        self.isHidden = isHidden
    }

    /// The row for `vault_category_folders`; an empty or unchanged name is stored as null so the category name stays.
    var row: [String: Any] {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ownName = trimmed.isEmpty || trimmed == category.title ? nil : trimmed
        return [
            "category": category.rawValue,
            "name": ownName ?? NSNull(),
            "color": color?.rawValue ?? NSNull(),
            "icon": icon?.rawValue ?? NSNull(),
            "is_hidden": isHidden,
        ] as [String: Any]
    }

    /// The same as text, for keeping it on the phone while the table does not exist yet.
    public var stored: [String: String] {
        var values = ["category": category.rawValue, "hidden": isHidden ? "1" : "0"]
        values["name"] = name
        values["color"] = color?.rawValue
        values["icon"] = icon?.rawValue
        return values
    }

    public init?(stored: [String: String]) {
        guard let category = stored["category"].flatMap(VaultCategory.init) else { return nil }
        self.init(
            category: category,
            name: stored["name"],
            color: stored["color"].flatMap(VaultFolderColor.init),
            icon: stored["icon"].flatMap(VaultFolderIcon.init),
            isHidden: stored["hidden"] == "1"
        )
    }
}

extension VaultCategory {
    /// The icon from the folder set that fits the category, for the editor when you have not picked one yet.
    public var folderStyleIcon: VaultFolderIcon {
        switch self {
        case .diplomas: .academicCap
        case .certificates: .checkBadge
        case .badges: .star
        case .projects: .wrenchScrewdriver
        case .workExperience, .internships: .briefcase
        case .skills: .paintBrush
        case .feedback: .chatBubble
        case .reflections: .documentText
        case .other: .folder
        }
    }
}
