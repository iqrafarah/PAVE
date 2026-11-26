import Foundation
import PAVECore
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

    /// Adds the code of one share to the Watch, next to the others there, with a short label of what it is.
    @discardableResult
    static func show(_ share: ProfileShare, url: URL) -> Bool {
        guard isAvailable, let png = ShareQRCode.png(for: url.absoluteString) else { return false }
        WCSession.default.transferUserInfo([key: [
            "id": share.id, "png": png, "title": share.title, "until": share.expiresAt.timeIntervalSince1970,
        ]])
        return true
    }

    /// Takes one share's code off the Watch, when it is paused or taken back; nil takes all of them.
    static func clear(_ shareID: String? = nil) {
        guard isAvailable else { return }
        var value: [String: Any] = ["clear": true]
        if let shareID { value["id"] = shareID }
        WCSession.default.transferUserInfo([key: value])
    }
}
