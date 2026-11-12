import Foundation
import PAVECore
import WatchConnectivity

/// Gives the Apple Watch the session of the signed-in user, so you never sign in on your wrist, but only after you
/// connected the Watch in Instellingen. Only a short-lived access token goes over; the refresh token stays here.
/// Signing out or disconnecting on the iPhone takes the session away from the Watch.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    /// Whether a Watch can be connected at all.
    enum Availability: Equatable {
        /// No Apple Watch is paired with this iPhone.
        case noWatch
        /// A Watch is paired, but PAVE is not on it.
        case appMissing
        case ready
    }

    private var auth: (any AuthService)?
    private var isSignedIn: () -> Bool = { false }
    /// Called on the main actor when the Watch was paired, unpaired or got PAVE, and when it asked for a session.
    var onChange: () -> Void = {}

    /// Called once at launch, also when the Watch wakes the app in the background to ask for a fresh session.
    func start(auth: any AuthService, isSignedIn: @escaping () -> Bool) {
        guard WCSession.isSupported() else { return }
        self.auth = auth
        self.isSignedIn = isSignedIn
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var availability: Availability {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isPaired else { return .noWatch }
        return session.isWatchAppInstalled ? .ready : .appMissing
    }

    func accountID() async -> String? {
        await auth?.accountID()
    }

    /// Connects the Watch for the signed-in account and hands it the session. Returns false when nobody is signed in.
    func connect() async -> Bool {
        guard isSignedIn(), let accountID = await accountID() else { return false }
        WatchConnection.connect(accountID: accountID)
        await push()
        return true
    }

    func disconnect() async {
        WatchConnection.disconnect()
        await push()
    }

    /// After signing in or out, and when the app comes to the front with a newer token.
    func update() {
        Task { await push() }
    }

    private func push() async {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(await currentMessage())
    }

    private func currentMessage() async -> [String: Any] {
        let session = await currentSession()
        let isConnected = WatchConnection.current(accountID: await accountID()) != nil
        return WatchLink.message(for: session, isConnected: isConnected)
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
        Task { @MainActor in
            await push()
            onChange()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// After switching to another Watch.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// The Watch was paired or unpaired, or PAVE was installed on it or removed.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            await push()
            onChange()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let reply = Reply(send: replyHandler)
        guard WatchLink.isSessionRequest(message) else {
            reply.send([:])
            return
        }
        Task { @MainActor in
            let answer = await currentMessage()
            if case .session = WatchLink.update(from: answer) {
                WatchConnection.markActive()
                onChange()
            }
            reply.send(answer)
        }
    }

    /// WatchConnectivity's reply handler may be called from any thread.
    nonisolated private struct Reply: @unchecked Sendable {
        let send: ([String: Any]) -> Void
    }
}
