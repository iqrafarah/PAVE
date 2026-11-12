import Foundation
import Observation
import PAVECore
import WatchConnectivity

/// The session the iPhone gave this Watch. There is no sign-in on the Watch: without a session from the iPhone,
/// the Watch asks you to sign in there, or to connect the Watch there when you are signed in but did not connect it.
@Observable
final class WatchSessionStore: NSObject, WCSessionDelegate {
    private(set) var session: WatchSession?
    /// The iPhone said you signed out, or never sent a session.
    private(set) var isSignedOut = false
    /// Signed in on the iPhone, but this Watch is not connected in Instellingen.
    private(set) var needsConnecting = false

    func start() {
        guard WCSession.isSupported() else {
            isSignedOut = true
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// A token that works for at least two more minutes; asks the iPhone for a new one when needed.
    func accessToken() async -> String? {
        if let session, session.isUsable() { return session.accessToken }
        await requestFromPhone()
        guard let session, session.isUsable() else { return nil }
        return session.accessToken
    }

    private func requestFromPhone() async {
        let connection = WCSession.default
        guard connection.activationState == .activated, connection.isReachable else { return }
        if let reply = await Self.askPhone()?.value { apply(reply) }
    }

    /// Nonisolated on purpose: WatchConnectivity calls the reply and error handlers on its own queue, and a handler
    /// that belongs to the main actor stops the app there.
    @concurrent nonisolated private static func askPhone() async -> Message? {
        await withCheckedContinuation { continuation in
            let once = Once(continuation)
            WCSession.default.sendMessage(WatchLink.sessionRequest) { reply in
                once.resume(Message(value: reply))
            } errorHandler: { _ in
                once.resume(nil)
            }
        }
    }

    private func apply(_ message: [String: Any]) {
        switch WatchLink.update(from: message) {
        case .session(let new):
            session = new
            isSignedOut = false
            needsConnecting = false
        case .signedOut:
            session = nil
            isSignedOut = true
            needsConnecting = false
        case .notConnected:
            session = nil
            isSignedOut = true
            needsConnecting = true
        case nil:
            break
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let context = Message(value: session.receivedApplicationContext)
        Task { @MainActor in
            if context.value.isEmpty {
                if self.session == nil { self.isSignedOut = true }
            } else {
                self.apply(context.value)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let context = Message(value: applicationContext)
        Task { @MainActor in self.apply(context.value) }
    }

    /// WatchConnectivity hands over plain dictionaries; they are only read on the main actor.
    nonisolated private struct Message: @unchecked Sendable {
        let value: [String: Any]
    }

    /// The reply and the error handler can both fire; the continuation must resume once.
    nonisolated private final class Once: @unchecked Sendable {
        private var continuation: CheckedContinuation<Message?, Never>?
        private let lock = NSLock()

        init(_ continuation: CheckedContinuation<Message?, Never>) {
            self.continuation = continuation
        }

        func resume(_ value: Message?) {
            lock.lock()
            let continuation = continuation
            self.continuation = nil
            lock.unlock()
            continuation?.resume(returning: value)
        }
    }
}
