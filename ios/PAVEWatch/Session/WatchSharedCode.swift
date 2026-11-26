import Foundation

/// A QR code of a share, approved on the iPhone, to have scanned from the wrist. There can be several, each with a short
/// label of what it is; each is kept until its share ends or the iPhone takes it off. Only the image, the label and until
/// when are kept, nothing of what is shared.
struct WatchSharedCode: Codable, Equatable, Identifiable {
    let id: String
    let png: Data
    let title: String
    let until: Date

    var isValid: Bool { until > .now }

    private static let key = "watchSharedCodes"

    /// From what the iPhone sent: a code to add, one or all to take off, or nothing for the codes.
    enum Update { case show(WatchSharedCode), clear(String?) }

    static func update(from userInfo: [String: Any]) -> Update? {
        guard let value = userInfo["shareQR"] as? [String: Any] else { return nil }
        if value["clear"] as? Bool == true { return .clear(value["id"] as? String) }
        guard let png = value["png"] as? Data, let title = value["title"] as? String, let until = value["until"] as? Double else { return nil }
        // An older iPhone app sends no id: it replaces the code it sent before.
        let id = value["id"] as? String ?? "single"
        return .show(WatchSharedCode(id: id, png: png, title: title, until: Date(timeIntervalSince1970: until)))
    }

    /// The codes that still work, newest first.
    static func load() -> [WatchSharedCode] {
        guard let data = UserDefaults.standard.data(forKey: key), let codes = try? JSONDecoder().decode([WatchSharedCode].self, from: data) else { return [] }
        return codes.filter(\.isValid)
    }

    static func save(_ codes: [WatchSharedCode]) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(codes.filter(\.isValid)) { defaults.set(data, forKey: key) }
        // The single code of the version before.
        for suffix in [".png", ".title", ".until", ".name", ".headline"] { defaults.removeObject(forKey: "watchSharedCode" + suffix) }
    }

    /// The list after an update: a code replaces the one with the same id and goes first.
    static func applying(_ update: Update, to codes: [WatchSharedCode]) -> [WatchSharedCode] {
        switch update {
        case .show(let code): [code] + codes.filter { $0.id != code.id && $0.isValid }
        case .clear(let id?): codes.filter { $0.id != id }
        case .clear(nil): []
        }
    }
}
