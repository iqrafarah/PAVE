import Foundation

/// A QR code of a share, approved on the iPhone, to have scanned from the wrist (at a fair). Kept on the Watch until
/// the share ends or the iPhone takes it off; it holds only the image, who it is for and until when.
struct WatchSharedCode: Equatable {
    let png: Data
    let title: String
    let until: Date

    var isValid: Bool { until > .now }

    private static let key = "watchSharedCode"

    /// From what the iPhone sent: a code, nil to take it off, or no change.
    enum Update { case show(WatchSharedCode), clear }

    static func update(from userInfo: [String: Any]) -> Update? {
        guard let value = userInfo["shareQR"] as? [String: Any] else { return nil }
        if value["clear"] as? Bool == true { return .clear }
        guard let png = value["png"] as? Data, let title = value["title"] as? String, let until = value["until"] as? Double else { return nil }
        return .show(WatchSharedCode(png: png, title: title, until: Date(timeIntervalSince1970: until)))
    }

    static func load() -> WatchSharedCode? {
        let defaults = UserDefaults.standard
        guard let png = defaults.data(forKey: key + ".png"), let title = defaults.string(forKey: key + ".title") else { return nil }
        let code = WatchSharedCode(png: png, title: title, until: Date(timeIntervalSince1970: defaults.double(forKey: key + ".until")))
        return code.isValid ? code : nil
    }

    static func save(_ code: WatchSharedCode?) {
        let defaults = UserDefaults.standard
        guard let code else {
            for suffix in [".png", ".title", ".until"] { defaults.removeObject(forKey: key + suffix) }
            return
        }
        defaults.set(code.png, forKey: key + ".png")
        defaults.set(code.title, forKey: key + ".title")
        defaults.set(code.until.timeIntervalSince1970, forKey: key + ".until")
    }
}

extension WatchSharedCode: Identifiable {
    var id: Double { until.timeIntervalSince1970 + Double(png.count) }
}
