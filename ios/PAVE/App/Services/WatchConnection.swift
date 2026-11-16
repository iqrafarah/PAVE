import Foundation

/// Whether the Apple Watch may use PAVE for the signed-in account. Pairing a Watch with the iPhone is not enough: you
/// connect it yourself in Instellingen, and you can disconnect it there or in Ingelogde apparaten.
struct WatchConnection: Equatable {
    let connectedAt: Date
    /// The last time the Watch asked for a session.
    let lastActiveAt: Date?

    private static let accountKey = "watchConnectedAccount"
    private static let connectedKey = "watchConnectedAt"
    private static let activeKey = "watchLastActiveAt"

    /// The connection of this account, or `nil` when the Watch is not connected for it.
    static func current(accountID: String?, defaults: UserDefaults = .standard) -> WatchConnection? {
        guard
            let accountID, defaults.string(forKey: accountKey) == accountID,
            let connectedAt = defaults.object(forKey: connectedKey) as? Date
        else { return nil }
        return WatchConnection(connectedAt: connectedAt, lastActiveAt: defaults.object(forKey: activeKey) as? Date)
    }

    static func connect(accountID: String, now: Date = .now, defaults: UserDefaults = .standard) {
        defaults.set(accountID, forKey: accountKey)
        defaults.set(now, forKey: connectedKey)
        defaults.removeObject(forKey: activeKey)
    }

    static func disconnect(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: accountKey)
        defaults.removeObject(forKey: connectedKey)
        defaults.removeObject(forKey: activeKey)
    }

    static func markActive(now: Date = .now, defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: accountKey) != nil else { return }
        defaults.set(now, forKey: activeKey)
    }
}
