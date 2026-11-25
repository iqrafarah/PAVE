import Foundation
import WatchConnectivity

/// Puts the QR code of a share on the Apple Watch, to have it scanned at a fair without taking out the phone. Only what
/// was approved on the iPhone goes: the code as an image, who it is for and until when. The Watch shows it until then.
enum ShareWatchBridge {
    static let key = "shareQR"

    static var isAvailable: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    @discardableResult
    /// `name` and `headline` make it your card on the wrist, as on the front of the card in Profiel.
    static func show(url: URL, title: String, until: Date, name: String? = nil, headline: String? = nil) -> Bool {
        guard isAvailable, let png = ShareQRCode.png(for: url.absoluteString) else { return false }
        var value: [String: Any] = ["png": png, "title": title, "until": until.timeIntervalSince1970]
        if let name, !name.isEmpty { value["name"] = name }
        if let headline, !headline.isEmpty { value["headline"] = headline }
        WCSession.default.transferUserInfo([key: value])
        return true
    }

    /// Takes it off the Watch, when the share is paused or taken back.
    static func clear() {
        guard isAvailable else { return }
        WCSession.default.transferUserInfo([key: ["clear": true]])
    }
}
