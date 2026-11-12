import Foundation

/// The accent colour of the app, chosen in Instellingen (Figma FEDDIES 1393:5359). `swatch` is the colour of the dot;
/// `accent` is that colour made just dark enough for white text on it (WCAG AA, 4.5:1), as buttons need. `custom` is a
/// colour you pick yourself; its value is `PaveProfile.customColor`.
public enum PaveThemeColor: String, CaseIterable, Identifiable, Sendable {
    case green, blue, gold, pink, orange, purple, red, lime, custom

    public var id: Self { self }

    /// The colours to choose from; `custom` comes after them with its own picker.
    public static let presets = allCases.filter { $0 != .custom }

    public var swatch: UInt32 {
        switch self {
        case .green, .custom: 0x355D4C
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
        case .green, .custom: 0x355D4C
        case .blue: 0x4C78B1
        case .gold: 0x927022
        case .pink: 0xAD5D7B
        case .orange: 0xA76544
        case .purple: 0x8466C0
        case .red: 0xB25E60
        case .lime: 0x7A7741
        }
    }

    /// An own colour made just dark enough for white text on it (WCAG AA, 4.5:1); a dark enough colour stays as it is.
    public static func readableAccent(for color: UInt32) -> UInt32 {
        var (red, green, blue) = (Double(color >> 16 & 0xFF), Double(color >> 8 & 0xFF), Double(color & 0xFF))
        while contrastWithWhite(red, green, blue) < 4.5 {
            (red, green, blue) = ((red * 0.97).rounded(.down), (green * 0.97).rounded(.down), (blue * 0.97).rounded(.down))
        }
        return UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue)
    }

    /// `#RRGGBB`, as the account stores an own colour.
    public static func hex(_ color: UInt32) -> String {
        String(format: "#%06X", color & 0xFFFFFF)
    }

    public static func color(hex: String) -> UInt32? {
        guard hex.count == 7, hex.first == "#", let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        return value
    }

    private static func contrastWithWhite(_ red: Double, _ green: Double, _ blue: Double) -> Double {
        func linear(_ channel: Double) -> Double {
            let value = channel / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return 1.05 / (luminance + 0.05)
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
    /// The own colour when `theme` is `custom`.
    public var customColor: UInt32?
    public var textSize: PaveTextSize
    public var vaultLayout: PaveVaultLayout
    /// False before the migration with the photo and the preferences (20261112170000) is applied.
    public var canChangeSettings: Bool

    public init(
        preferredName: String? = nil, fullName: String? = nil, email: String? = nil, avatarPath: String? = nil,
        avatarURL: URL? = nil, theme: PaveThemeColor = .green, customColor: UInt32? = nil, textSize: PaveTextSize = .standard,
        vaultLayout: PaveVaultLayout = .grid, canChangeSettings: Bool = true
    ) {
        self.preferredName = preferredName
        self.fullName = fullName
        self.email = email
        self.avatarPath = avatarPath
        self.avatarURL = avatarURL
        self.theme = theme
        self.customColor = customColor
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
    /// The columns or the bucket of migration 20261112170000 are not there yet.
    case notSetUp
    case nameTooLong
    case unavailable

    public init(_ error: any Error) { self = (error as? ProfileError) ?? .unavailable }
}
