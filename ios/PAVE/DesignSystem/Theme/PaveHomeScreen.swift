import PAVECore
import UIKit

/// The theme colour on the Home Screen: the app icon can only be one of the icons in the app, so it takes the closest
/// theme colour. iOS tells you each time the icon changes, so it only changes when a colour is chosen, never while you
/// are still picking one.
enum PaveHomeScreen {
    /// The icon of a theme colour; nil is the main icon in PAVE green.
    static func iconName(theme: PaveThemeColor, customColor: UInt32?) -> String? {
        let preset = theme == .custom ? customColor.map(PaveThemeColor.nearestPreset(to:)) ?? .green : theme
        guard preset != .green else { return nil }
        return "AppIcon" + preset.rawValue.prefix(1).uppercased() + preset.rawValue.dropFirst()
    }

    static func update(theme: PaveThemeColor, customColor: UInt32?) {
        let application = UIApplication.shared
        let name = iconName(theme: theme, customColor: customColor)
        guard application.supportsAlternateIcons, application.alternateIconName != name else { return }
        Task {
            try? await application.setAlternateIconName(name)
        }
    }
}
