import PAVECore
import SwiftUI
import UIKit

/// The chosen theme colour. Views that use `Color.paveAccent` read it while they draw, so Observation redraws exactly
/// those views when it changes: the whole app takes the new colour at once and you stay where you are.
@Observable
final class PaveThemeStore {
    static let shared = PaveThemeStore()
    var theme = PaveAppearance.theme
    var customColor = PaveAppearance.customColor
    /// While signing in or making an account: the controls take eduID's blue, as on the web (AuthEduidCard). The
    /// logo and the background around them stay PAVE.
    var usesEduID = false
    static let eduIDBlue: UInt32 = 0x0077C8

    /// The accent as a colour value, or nil for PAVE green, which uses its own colour tokens.
    var accent: UInt32? {
        usesEduID ? Self.eduIDBlue : themeAccent
    }

    /// The theme colour itself, also while eduID's blue is in use.
    var themeAccent: UInt32? {
        switch theme {
        case .green: nil
        case .custom: customColor.map(PaveThemeColor.readableAccent(for:))
        default: theme.accent
        }
    }
}

extension Color {
    /// The accent of the app: PAVE green, or the theme colour chosen in Instellingen. Ayla's orb, the Watch and the
    /// widgets keep PAVE green. In dark mode a livelier shade that still carries white text (web darkThemeColours).
    static var paveAccent: Color {
        let accent = PaveThemeStore.shared.accent
        let light = accent.map { UIColor(hex: $0) } ?? UIColor(resource: .brandGreen)
        let dark = PaveDarkColors.fill(for: accent ?? PaveDarkColors.green)
        return Color(uiColor: .dynamic(light: light, dark: dark))
    }

    /// The theme colour of PAVE, also on the eduID screens: for the logo and the background around the card.
    static var paveThemeAccent: Color {
        let accent = PaveThemeStore.shared.themeAccent
        let light = accent.map { UIColor(hex: $0) } ?? UIColor(resource: .brandGreen)
        let dark = PaveDarkColors.fill(for: accent ?? PaveDarkColors.green)
        return Color(uiColor: .dynamic(light: light, dark: dark))
    }

    /// Cards, fields, sheets and other raised surfaces: white, and an almost black grey in dark mode (web --color-panel).
    static let panel = Color(uiColor: .dynamic(light: .white, dark: UIColor(hex: 0x161616)))
}

/// The dark versions of the theme colour, worked out as the web does (themeColours.ts, darkThemeColours): filled
/// controls get the liveliest shade that still carries white text, tinted surfaces deep clean shades of the hue.
enum PaveDarkColors {
    static let green: UInt32 = 0x355D4C
    private static let raised: UInt32 = 0x1F1F1F

    static func fill(for hex: UInt32) -> UIColor {
        let (hue, saturation, _) = hsl(hex)
        guard saturation > 0.12 else { return UIColor(hex: hex) }
        let vivid = min(0.85, max(0.5, saturation * 1.25))
        var readable: UInt32?
        var lightness = 0.7
        while lightness > 0.05 {
            let candidate = fromHsl(hue, vivid, lightness)
            if contrast(candidate, 0xFFFFFF) >= 4.6 {
                readable = readable ?? candidate
                if contrast(candidate, raised) >= 3 { return UIColor(hex: candidate) }
            }
            lightness -= 0.01
        }
        return UIColor(hex: readable ?? hex)
    }

    /// The accent as text and lines on dark surfaces, such as the focus ring.
    static func text(for hex: UInt32) -> UIColor {
        let (hue, saturation, _) = hsl(hex)
        guard saturation > 0.12 else { return UIColor(hex: hex) }
        return UIColor(hex: fromHsl(hue, min(0.85, max(0.5, saturation * 1.25)), 0.7))
    }

    /// A deep shade of the hue for tinted surfaces; `lightness` 0.1 to 0.2.
    static func surface(for hex: UInt32, lightness: Double) -> UIColor {
        let (hue, saturation, _) = hsl(hex)
        return UIColor(hex: fromHsl(hue, min(0.24, saturation), lightness))
    }

    private static func channels(_ hex: UInt32) -> (Double, Double, Double) {
        (Double(hex >> 16 & 0xFF) / 255, Double(hex >> 8 & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    private static func luminance(_ hex: UInt32) -> Double {
        let (r, g, b) = channels(hex)
        func linear(_ value: Double) -> Double { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    static func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        let (a, b) = (luminance(first), luminance(second))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func hsl(_ hex: UInt32) -> (Double, Double, Double) {
        let (r, g, b) = channels(hex)
        let high = max(r, g, b), low = min(r, g, b)
        let lightness = (high + low) / 2
        let delta = high - low
        guard delta > 0 else { return (0, 0, lightness) }
        let saturation = delta / (1 - abs(2 * lightness - 1))
        let hue: Double = if high == r { ((g - b) / delta + 6).truncatingRemainder(dividingBy: 6) } else if high == g { (b - r) / delta + 2 } else { (r - g) / delta + 4 }
        return (hue * 60, saturation, lightness)
    }

    private static func fromHsl(_ hue: Double, _ saturation: Double, _ lightness: Double) -> UInt32 {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        func channel(_ n: Double) -> UInt32 {
            let k = (n + hue / 30).truncatingRemainder(dividingBy: 12)
            let value = lightness - chroma / 2 * max(-1, min(k - 3, 9 - k, 1))
            return UInt32(max(0, min(255, (value * 255).rounded())))
        }
        return channel(0) << 16 | channel(8) << 8 | channel(4)
    }
}

extension ShapeStyle where Self == Color {
    static var paveAccent: Color { Color.paveAccent }
    static var paveSurfaceTint: Color { Color.paveSurfaceTint }
    static var paveDropZone: Color { Color.paveDropZone }
    static var paveFocusRing: Color { Color.paveFocusRing }
    static var paveVerifiedSurface: Color { Color.paveVerifiedSurface }
    static var paveThinkingGlow: Color { Color.paveThinkingGlow }
}

extension Color {
    /// A light or dark shade of the theme colour, as light as the PAVE green token it replaces (0 is the colour
    /// itself, 1 is white). With the green theme it is exactly that token.
    /// `dark` is what the tint is on a dark screen: a deep surface of that lightness, or the accent as text (nil).
    private static func paveTint(_ whiteness: Double, dark: Double?, green: Color) -> Color {
        guard let accent = PaveThemeStore.shared.accent else { return green }
        let light = UIColor(Color(uiColor: UIColor(hex: accent)).mix(with: .white, by: whiteness))
        let night = dark.map { PaveDarkColors.surface(for: accent, lightness: $0) } ?? PaveDarkColors.text(for: accent)
        return Color(uiColor: .dynamic(light: light, dark: night))
    }

    static var paveSurfaceTint: Color { paveTint(0.89, dark: 0.135, green: .surfaceTint) }
    static var paveDropZone: Color { paveTint(0.955, dark: 0.1, green: .dropZone) }
    static var paveFocusRing: Color { paveTint(0.67, dark: nil, green: .focusRing) }
    static var paveVerifiedSurface: Color { paveTint(0.93, dark: 0.115, green: .statusVerifiedSurface) }
    static var paveThinkingGlow: Color { paveTint(0.1, dark: nil, green: .thinkingGlow) }

    /// The seven shades of Ayla's orb, light to dark.
    static func paveOrbShade(_ index: Int) -> Color {
        let greens: [Color] = [.orbShade0, .orbShade1, .orbShade2, .orbShade3, .orbShade4, .orbShade5, .orbShade6]
        let whiteness = [0.93, 0.83, 0.67, 0.42, 0.2, 0.05, 0]
        // The orb keeps its own light shades in dark mode too: it is a light, not a surface.
        guard let accent = PaveThemeStore.shared.accent else { return greens[index] }
        return Color(uiColor: UIColor(hex: accent)).mix(with: .white, by: whiteness[index])
    }
}

extension UIColor {
    /// A colour for light and one for dark mode. Nonisolated: UIKit and SwiftUI resolve it on any thread while drawing.
    nonisolated static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    convenience init(hex: UInt32) {
        self.init(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// The look the account chose: theme colour, text size and how the vault opens. Kept on this device too, so the app
/// starts in the right colour before the account is loaded.
enum PaveAppearance {
    static let themeKey = "paveThemeColor"
    static let customColorKey = "paveCustomColor"
    static let textSizeKey = "paveTextSize"
    static let vaultLayoutKey = "paveVaultLayout"
    static let displayModeKey = "paveDisplayMode"

    /// Licht, Donker or Automatisch (the setting of the device). Kept here so PAVE starts in it before the account loads.
    static var displayMode: PaveDisplayMode {
        UserDefaults.standard.string(forKey: displayModeKey).flatMap(PaveDisplayMode.init(rawValue:)) ?? .auto
    }

    static var theme: PaveThemeColor {
        UserDefaults.standard.string(forKey: themeKey).flatMap(PaveThemeColor.init(rawValue:)) ?? .green
    }

    static var customColor: UInt32? {
        UserDefaults.standard.string(forKey: customColorKey).flatMap(PaveThemeColor.color(hex:))
    }

    static var vaultLayout: PaveVaultLayout {
        UserDefaults.standard.string(forKey: vaultLayoutKey).flatMap(PaveVaultLayout.init(rawValue:)) ?? .grid
    }

    static func apply(_ theme: PaveThemeColor, customColor: UInt32?) {
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
        UserDefaults.standard.set(customColor.map(PaveThemeColor.hex), forKey: customColorKey)
        PaveThemeStore.shared.customColor = customColor
        PaveThemeStore.shared.theme = theme
    }

    /// Ayla's orb in the theme colour.
    static var orbPalette: [Color] { (0..<7).map(Color.paveOrbShade) }

    /// Licht or Donker for every window of PAVE, sheets included; Automatisch follows the device.
    @MainActor
    static func apply(_ mode: PaveDisplayMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: displayModeKey)
        let style: UIUserInterfaceStyle = switch mode {
        case .auto: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows { window.overrideUserInterfaceStyle = style }
        }
    }

    /// At launch: the stored look, also for widgets placed before the app shared its colour with them.
    static func applyStored() {
        apply(theme, customColor: customColor)
        PaveHomeScreen.updateWidgets(theme: theme, customColor: customColor)
    }
}

extension DynamicTypeSize {
    /// One step smaller for Klein and two steps larger for Groot than what the device is set to; Standaard follows it.
    func shifted(by textSize: PaveTextSize) -> DynamicTypeSize {
        let all = DynamicTypeSize.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        let offset = switch textSize {
        case .small: -1
        case .standard: 0
        case .large: 2
        }
        return all[min(max(index + offset, 0), all.count - 1)]
    }
}
