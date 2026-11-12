import PAVECore
import Security
import UIKit
import WidgetKit

/// The theme colour on the Home Screen. The widgets read it from a Keychain item the app and the widgets share, so
/// they show exactly the chosen colour. The app icon can only be one of the icons in the app, so it takes the closest
/// theme colour; iOS tells you each time the icon changes, so it only changes when a colour is chosen, never while you
/// are still picking one.
enum PaveHomeScreen {
    static let widgetAccentService = "nl.fontys.pave.theme"
    static let widgetAccentAccount = "widgetAccent"

    static func update(theme: PaveThemeColor, customColor: UInt32?) {
        updateWidgets(theme: theme, customColor: customColor)
        updateIcon(theme: theme, customColor: customColor)
    }

    /// The icon of a theme colour; nil is the main icon in PAVE green.
    static func iconName(theme: PaveThemeColor, customColor: UInt32?) -> String? {
        let preset = theme == .custom ? customColor.map(PaveThemeColor.nearestPreset(to:)) ?? .green : theme
        guard preset != .green else { return nil }
        return "AppIcon" + preset.rawValue.prefix(1).uppercased() + preset.rawValue.dropFirst()
    }

    static func widgetAccent(theme: PaveThemeColor, customColor: UInt32?) -> UInt32 {
        guard theme == .custom else { return theme.accent }
        return customColor.map(PaveThemeColor.readableAccent(for:)) ?? PaveThemeColor.green.accent
    }

    static func updateWidgets(theme: PaveThemeColor, customColor: UInt32?) {
        let hex = PaveThemeColor.hex(widgetAccent(theme: theme, customColor: customColor))
        guard let group = Bundle.main.object(forInfoDictionaryKey: "PaveKeychainGroup") as? String,
              storedWidgetAccent(group: group) != hex else { return }
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: widgetAccentService,
            kSecAttrAccount as String: widgetAccentAccount,
            kSecAttrAccessGroup as String: group,
        ]
        SecItemDelete(item as CFDictionary)
        var added = item
        added[kSecValueData as String] = Data(hex.utf8)
        added[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(added as CFDictionary, nil) == errSecSuccess else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func storedWidgetAccent(group: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: widgetAccentService,
            kSecAttrAccount as String: widgetAccentAccount,
            kSecAttrAccessGroup as String: group,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func updateIcon(theme: PaveThemeColor, customColor: UInt32?) {
        let application = UIApplication.shared
        let name = iconName(theme: theme, customColor: customColor)
        guard application.supportsAlternateIcons, application.alternateIconName != name else { return }
        Task {
            try? await application.setAlternateIconName(name)
        }
    }
}
