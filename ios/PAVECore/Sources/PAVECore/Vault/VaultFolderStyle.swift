/// The colour of a folder you made: one of the theme colours of Instellingen, or one of your own. The raw values are what
/// `vault_folders.color` stores: a name, or `#rrggbb` in lower case (migration 20261119120000).
public enum VaultFolderColor: Hashable, Sendable {
    case green
    case blue
    case gold
    case rose
    case rust
    case purple
    case red
    case lime
    /// Only kept for folders that already have it; it is no longer offered.
    case slate
    case custom(UInt32)

    /// The colours to choose from, in the order of the themes in Instellingen.
    public static let presets: [VaultFolderColor] = [.green, .blue, .gold, .rose, .rust, .purple, .red, .lime]

    /// Every named colour, for checking against the database.
    public static let named: [VaultFolderColor] = presets + [.slate]

    public init?(rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespaces).lowercased()
        if let named = Self.named.first(where: { $0.rawValue == value }) {
            self = named
        } else if value.wholeMatch(of: /#[0-9a-f]{6}/) != nil, let hex = UInt32(value.dropFirst(), radix: 16) {
            self = .custom(hex)
        } else {
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .green: "green"
        case .blue: "blue"
        case .gold: "gold"
        case .rose: "rose"
        case .rust: "rust"
        case .purple: "purple"
        case .red: "red"
        case .lime: "lime"
        case .slate: "slate"
        case .custom(let hex): "#" + String(format: "%06x", hex & 0xFFFFFF)
        }
    }

    /// The same colours as the web (`VAULT_FOLDER_COLORS`): the theme swatches of Instellingen. Green follows the accent.
    public var hex: UInt32 {
        switch self {
        case .green: PaveThemeColor.green.swatch
        case .blue: PaveThemeColor.blue.swatch
        case .gold: PaveThemeColor.gold.swatch
        case .rose: PaveThemeColor.pink.swatch
        case .rust: PaveThemeColor.orange.swatch
        case .purple: PaveThemeColor.purple.swatch
        case .red: PaveThemeColor.red.swatch
        case .lime: PaveThemeColor.lime.swatch
        case .slate: 0x4A5250
        case .custom(let hex): hex
        }
    }

    public var isCustom: Bool {
        if case .custom = self { true } else { false }
    }

    public var title: String {
        switch self {
        case .green: "Groen"
        case .blue: "Blauw"
        case .gold: "Goud"
        case .rose: "Roze"
        case .rust: "Oranje"
        case .purple: "Paars"
        case .red: "Rood"
        case .lime: "Limoen"
        case .slate: "Grijs"
        case .custom: "Eigen kleur"
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
