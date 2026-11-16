import UIKit

/// The quick actions on the app icon (press and hold PAVE on the Home Screen): "Praat met Ayla" and "Nieuw gesprek".
/// Their types are the `PaveLink` values, so they go the same way as Siri and the widgets: through the PIN first.
final class PaveAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let item = options.shortcutItem { PaveSceneDelegate.handle(item) }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = PaveSceneDelegate.self
        return configuration
    }
}

final class PaveSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem) async -> Bool {
        Self.handle(shortcutItem)
    }

    @discardableResult
    static func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard let link = PaveLink(rawValue: item.type) else { return false }
        PaveLinkInbox.send(link)
        return true
    }
}
