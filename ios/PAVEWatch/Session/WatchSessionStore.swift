import Foundation
import Observation
import PAVECore
import WatchConnectivity
import WatchKit

/// The session the iPhone gave this Watch. There is no sign-in on the Watch: without a session from the iPhone,
/// the Watch asks you to sign in there, or to connect the Watch there when you are signed in but did not connect it.
@Observable
final class WatchSessionStore: NSObject, WCSessionDelegate {
    private(set) var session: WatchSession?
    /// The iPhone said you signed out, or never sent a session.
    private(set) var isSignedOut = false
    /// Signed in on the iPhone, but this Watch is not connected in Instellingen.
    private(set) var needsConnecting = false
    /// The QR codes of shares the iPhone put here, newest first; each shown until it ends.
    private(set) var sharedCodes: [WatchSharedCode] = WatchSharedCode.load()
    /// The code that just arrived, to bring up by itself.
    private(set) var newCodeID: String?
    /// The next step with your applications, from the iPhone.
    private(set) var nextStep: NextStep? = WatchNextStep.load()
    /// What just happened on the iPhone, shown as a card with a tap on the wrist until it is dismissed.
    var event: WatchEvent?
    /// The plan you are on, as the iPhone last sent it.
    private(set) var plan: WatchEvent? = WatchSessionStore.loadPlan()

    private static let planKey = "watchPlan"

    private static func loadPlan() -> WatchEvent? {
        UserDefaults.standard.data(forKey: planKey).flatMap { WatchEvent.from([WatchEvent.key: $0]) }
    }

    /// An event from the iPhone: the plan is kept quietly, everything else comes up with a tap.
    private func receive(_ event: WatchEvent) {
        if case .plan = event {
            plan = event
            UserDefaults.standard.set(event.data, forKey: Self.planKey)
            return
        }
        self.event = event
        WKInterfaceDevice.current().play(.notification)
    }

    /// Asks the iPhone to do something you said Ja to; its reply says what came of it. Queued when the iPhone cannot be
    /// reached now, and nil then.
    func send(_ request: WatchRequest) async -> String? {
        let connection = WCSession.default
        guard connection.activationState == .activated else { return nil }
        guard connection.isReachable else {
            connection.transferUserInfo(request.message)
            return nil
        }
        let reply = await Self.ask(request.message)
        return reply?.value["said"] as? String ?? (reply?.value["ok"] as? Bool == true ? "" : nil)
    }

    @concurrent nonisolated private static func ask(_ message: [String: Any]) async -> Message? {
        let message = Message(value: message)
        return await withCheckedContinuation { continuation in
            let once = Once(continuation)
            WCSession.default.sendMessage(message.value) { reply in
                once.resume(Message(value: reply))
            } errorHandler: { _ in
                once.resume(nil)
            }
        }
    }

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
        WatchPreferences.shared.apply(message)
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

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let message = Message(value: userInfo)
        Task { @MainActor in
            if let event = WatchEvent.from(message.value) { self.receive(event) }
            if let update = WatchSharedCode.update(from: message.value) {
                self.sharedCodes = WatchSharedCode.applying(update, to: self.sharedCodes)
                WatchSharedCode.save(self.sharedCodes)
                if case .show(let code) = update { self.newCodeID = code.id }
            }
            switch WatchNextStep.update(from: message.value) {
            case .show(let step):
                self.nextStep = step
                WatchNextStep.save(step)
            case .clear:
                self.nextStep = nil
                WatchNextStep.save(nil)
            case nil:
                break
            }
        }
    }

    /// An event sent while the Watch app is open: it comes at once.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let message = Message(value: message)
        Task { @MainActor in
            if let event = WatchEvent.from(message.value) { self.receive(event) }
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
