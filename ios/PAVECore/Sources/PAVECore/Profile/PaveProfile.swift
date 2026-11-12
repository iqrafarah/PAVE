import Foundation

/// The accent colour of the app, chosen in Instellingen (Figma FEDDIES 1393:5359). `swatch` is the colour of the dot;
/// `accent` is that colour made just dark enough for white text on it (WCAG AA, 4.5:1), as buttons need.
public enum PaveThemeColor: String, CaseIterable, Identifiable, Sendable {
    case green, blue, gold, pink, orange, purple, red, lime

    public var id: Self { self }

    public var swatch: UInt32 {
        switch self {
        case .green: 0x355D4C
        case .blue: 0x4F7DB8
        case .gold: 0xC89A2E
        case .pink: 0xC56A8C
        case .orange: 0xC97A52
        case .purple: 0x8A6AC8
        case .red: 0xC86A6C
        case .lime: 0xC8C36A
        }
    }

    public var accent: UInt32 {
        switch self {
        case .green: 0x355D4C
        case .blue: 0x4C78B1
        case .gold: 0x927022
        case .pink: 0xAD5D7B
        case .orange: 0xA76544
        case .purple: 0x8466C0
        case .red: 0xB25E60
        case .lime: 0x7A7741
        }
    }
}

/// Small, the size the device is set to, or large.
public enum PaveTextSize: String, CaseIterable, Identifiable, Sendable {
    case small, standard, large
    public var id: Self { self }
}

/// How the vault opens. The vault can still switch for a moment; the next time it opens like this again.
public enum PaveVaultLayout: String, CaseIterable, Identifiable, Sendable {
    case list, grid
    public var id: Self { self }
}

/// The signed-in account as Instellingen shows it. The full name and e-mail come from the school or organisation.
public struct PaveProfile: Equatable, Sendable {
    public var preferredName: String?
    public var fullName: String?
    public var email: String?
    /// An own photo in the pave-avatars bucket.
    public var avatarPath: String?
    /// A photo the organisation set, used when there is no own photo.
    public var avatarURL: URL?
    public var theme: PaveThemeColor
    public var textSize: PaveTextSize
    public var vaultLayout: PaveVaultLayout
    /// False before the migration with the photo and the preferences (20261112160000) is applied.
    public var canChangeSettings: Bool

    public init(
        preferredName: String? = nil, fullName: String? = nil, email: String? = nil, avatarPath: String? = nil,
        avatarURL: URL? = nil, theme: PaveThemeColor = .green, textSize: PaveTextSize = .standard,
        vaultLayout: PaveVaultLayout = .grid, canChangeSettings: Bool = true
    ) {
        self.preferredName = preferredName
        self.fullName = fullName
        self.email = email
        self.avatarPath = avatarPath
        self.avatarURL = avatarURL
        self.theme = theme
        self.textSize = textSize
        self.vaultLayout = vaultLayout
        self.canChangeSettings = canChangeSettings
    }

    /// The name to show: the own name, else the first name from the full name.
    public var displayName: String? {
        if let preferred = preferredName?.trimmingCharacters(in: .whitespaces), !preferred.isEmpty { return preferred }
        return fullName?.split(separator: " ").first.map(String.init)
    }

    public static let maximumNameLength = 60

    /// The name to save, or nil to clear it; throws when it is too long.
    public static func cleanedName(_ name: String) throws -> String? {
        let clean = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if clean.count > maximumNameLength { throw ProfileError.nameTooLong }
        return clean.isEmpty ? nil : clean
    }
}

public enum ProfileError: Error, Equatable, Sendable {
    case notSignedIn
    case notAllowed
    case noConnection
    /// The columns or the bucket of migration 20261112160000 are not there yet.
    case notSetUp
    case nameTooLong
    case unavailable

    public init(_ error: any Error) { self = (error as? ProfileError) ?? .unavailable }
}
