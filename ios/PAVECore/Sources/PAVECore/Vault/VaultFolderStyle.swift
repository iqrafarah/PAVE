/// The colour of a folder you made. The raw values are what `vault_folders.color` stores.
public enum VaultFolderColor: String, CaseIterable, Sendable {
    case green
    case blue
    case purple
    case rust
    case rose
    case slate

    public var title: String {
        switch self {
        case .green: "Groen"
        case .blue: "Blauw"
        case .purple: "Paars"
        case .rust: "Roest"
        case .rose: "Roze"
        case .slate: "Grijs"
        }
    }
}

/// The icon on a folder you made. The raw values are what `vault_folders.icon` stores, and match Heroicons names.
public enum VaultFolderIcon: String, CaseIterable, Sendable {
    case folder
    case briefcase
    case academicCap = "academic-cap"
    case checkBadge = "check-badge"
    case wrenchScrewdriver = "wrench-screwdriver"
    case chatBubble = "chat-bubble-left-ellipsis"
    case star
    case heart
    case codeBracket = "code-bracket"
    case lightBulb = "light-bulb"
    case rocket = "rocket-launch"
    case globe = "globe-europe-africa"
    case paintBrush = "paint-brush"
    case documentText = "document-text"
    case userGroup = "user-group"
    case trophy

    /// For VoiceOver.
    public var title: String {
        switch self {
        case .folder: "Map"
        case .briefcase: "Koffer"
        case .academicCap: "Afstudeerhoed"
        case .checkBadge: "Keurmerk"
        case .wrenchScrewdriver: "Gereedschap"
        case .chatBubble: "Tekstballon"
        case .star: "Ster"
        case .heart: "Hart"
        case .codeBracket: "Code"
        case .lightBulb: "Lampje"
        case .rocket: "Raket"
        case .globe: "Wereldbol"
        case .paintBrush: "Kwast"
        case .documentText: "Document"
        case .userGroup: "Groep"
        case .trophy: "Beker"
        }
    }
}
