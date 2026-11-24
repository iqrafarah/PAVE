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
    static func show(url: URL, title: String, until: Date) -> Bool {
        guard isAvailable, let png = ShareQRCode.png(for: url.absoluteString) else { return false }
        WCSession.default.transferUserInfo([key: ["png": png, "title": title, "until": until.timeIntervalSince1970]])
        return true
    }

    /// Takes it off the Watch, when the share is paused or taken back.
    static func clear() {
        guard isAvailable else { return }
        WCSession.default.transferUserInfo([key: ["clear": true]])
    }
}
