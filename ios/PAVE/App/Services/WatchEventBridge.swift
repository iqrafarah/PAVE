import Foundation
import PAVECore
import WatchConnectivity

/// The live line to the Watch: what happens on the iPhone taps the wrist (someone looked, an invitation, a stand,
/// something Ayla set up), and what you decide on the Watch comes back here to be carried out. Nothing goes when there
/// is no Watch with PAVE on it.
@MainActor
enum WatchEventBridge {
    /// Answers an invitation from the fair; set by the main screen, which has the sharing model.
    static var onAnswer: ((String, Bool) async -> Bool)?
    /// Carries out actions Ayla proposed on the Watch and you said Ja to; returns what to tell the Watch.
    static var onActions: (([AylaAppAction]) async -> String)?

    private static var lastPlan: WatchEvent?

    static func send(_ event: WatchEvent) {
        guard ShareWatchBridge.isAvailable, let data = event.data else { return }
        if case .plan = event {
            // The plan only goes again when it changed.
            guard lastPlan != event else { return }
            lastPlan = event
        }
        let session = WCSession.default
        let message = [WatchEvent.key: data]
        // Straight away while the Watch app is open; otherwise queued, so it is there when it opens.
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in session.transferUserInfo(message) }
        } else {
            session.transferUserInfo(message)
        }
    }

    /// A request from the Watch; returns the reply for it.
    static func handle(_ request: WatchRequest) async -> [String: Any] {
        switch request {
        case .answerInvitation(let id, let accepted):
            let done = await onAnswer?(id, accepted) ?? false
            return ["ok": done]
        case .actions(let actions):
            guard let onActions else { return ["ok": false, "said": "Open PAVE op je iPhone en probeer het opnieuw."] }
            let said = await onActions(actions)
            return ["ok": true, "said": said]
        }
    }
}
