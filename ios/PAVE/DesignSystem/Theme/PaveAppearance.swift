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

    /// The accent as a colour value, or nil for PAVE green, which uses its own colour tokens.
    var accent: UInt32? {
        switch theme {
        case .green: nil
        case .custom: customColor.map(PaveThemeColor.readableAccent(for:))
        default: theme.accent
        }
    }
}

extension Color {
    /// The accent of the app: PAVE green, or the theme colour chosen in Instellingen. Ayla's orb, the Watch and the
    /// widgets keep PAVE green.
    static var paveAccent: Color {
        PaveThemeStore.shared.accent.map { Color(uiColor: UIColor(hex: $0)) } ?? Color(.brandGreen)
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
    private static func paveTint(_ whiteness: Double, green: Color) -> Color {
        guard let accent = PaveThemeStore.shared.accent else { return green }
        return Color(uiColor: UIColor(hex: accent)).mix(with: .white, by: whiteness)
    }

    static var paveSurfaceTint: Color { paveTint(0.89, green: .surfaceTint) }
    static var paveDropZone: Color { paveTint(0.955, green: .dropZone) }
    static var paveFocusRing: Color { paveTint(0.67, green: .focusRing) }
    static var paveVerifiedSurface: Color { paveTint(0.93, green: .statusVerifiedSurface) }
    static var paveThinkingGlow: Color { paveTint(0.1, green: .thinkingGlow) }

    /// The seven shades of Ayla's orb, light to dark.
    static func paveOrbShade(_ index: Int) -> Color {
        let greens: [Color] = [.orbShade0, .orbShade1, .orbShade2, .orbShade3, .orbShade4, .orbShade5, .orbShade6]
        let whiteness = [0.93, 0.83, 0.67, 0.42, 0.2, 0.05, 0]
        return paveTint(whiteness[index], green: greens[index])
    }
}

extension UIColor {
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
