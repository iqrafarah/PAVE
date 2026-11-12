import Foundation
import PAVECore
import WatchConnectivity

/// Gives the Apple Watch the session of the signed-in user, so you never sign in on your wrist. Only a short-lived
/// access token goes over; the refresh token stays here. Signing out on the iPhone signs the Watch out too.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    private var auth: (any AuthService)?
    private var isSignedIn: () -> Bool = { false }

    /// Called once at launch, also when the Watch wakes the app in the background to ask for a fresh session.
    func start(auth: any AuthService, isSignedIn: @escaping () -> Bool) {
        guard WCSession.isSupported() else { return }
        self.auth = auth
        self.isSignedIn = isSignedIn
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// After signing in or out, and when the app comes to the front with a newer token.
    func update() {
        Task { await push() }
    }

    private func push() async {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(WatchLink.message(for: await currentSession()))
    }

    /// Nothing with the demo account: its token means nothing to the server.
    private func currentSession(bundle: Bundle = .main) async -> WatchSession? {
        guard
            isSignedIn(),
            let auth, !(auth is MockAuthService),
            let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString), url.host() != nil,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String, !key.isEmpty,
            let token = await auth.accessToken()
        else { return nil }
        return WatchSession(projectURL: url, publishableKey: key, accessToken: token)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in await push() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// After switching to another Watch.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let reply = Reply(send: replyHandler)
        guard WatchLink.isSessionRequest(message) else {
            reply.send([:])
            return
        }
        Task { @MainActor in
            reply.send(WatchLink.message(for: await currentSession()))
        }
    }

    /// WatchConnectivity's reply handler may be called from any thread.
    nonisolated private struct Reply: @unchecked Sendable {
        let send: ([String: Any]) -> Void
    }
}
