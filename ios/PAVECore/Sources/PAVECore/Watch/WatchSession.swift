import Foundation

/// What the iPhone gives the Watch, so the Watch can talk to Ayla as the signed-in user. The Watch never signs in
/// itself: no password or authenticator code on the wrist, and when you sign out on the iPhone, the Watch is out too.
/// Only a short-lived access token travels; the refresh token stays on the iPhone, so the two never refresh the same
/// session and log each other out.
public struct WatchSession: Codable, Equatable, Sendable {
    public var projectURL: URL
    /// The public key of the Supabase project; it is in every app and not a secret.
    public var publishableKey: String
    public var accessToken: String

    public init(projectURL: URL, publishableKey: String, accessToken: String) {
        self.projectURL = projectURL
        self.publishableKey = publishableKey
        self.accessToken = accessToken
    }

    /// When the access token stops working, from its `exp` claim.
    public var expiresAt: Date? {
        (Self.claims(of: accessToken)?["exp"] as? Double).map { Date(timeIntervalSince1970: $0) }
    }

    /// Two-step verification passed; Ayla refuses anything less.
    public var isTwoStepVerified: Bool {
        Self.claims(of: accessToken)?["aal"] as? String == "aal2"
    }

    /// Still good for at least `margin` seconds, so a question does not fail halfway.
    public func isUsable(at now: Date = .now, margin: TimeInterval = 120) -> Bool {
        guard isTwoStepVerified, let expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) > margin
    }

    static func claims(of token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

/// The messages between the iPhone and the Watch (WatchConnectivity dictionaries).
public enum WatchLink {
    public enum Update: Equatable, Sendable {
        case session(WatchSession)
        case signedOut
        /// Signed in on the iPhone, but this Watch is not connected in Instellingen (yet), or was disconnected.
        case notConnected
    }

    static let sessionKey = "session"
    static let signedOutKey = "signedOut"
    static let notConnectedKey = "notConnected"
    static let requestKey = "request"

    /// The Watch asks for a fresh session; the iPhone answers with `message(for:)`.
    public static var sessionRequest: [String: Any] { [requestKey: sessionKey] }

    public static func isSessionRequest(_ message: [String: Any]) -> Bool {
        message[requestKey] as? String == sessionKey
    }

    /// `nil` means signed out on the iPhone. A Watch that is not connected gets no session, even when signed in.
    public static func message(for session: WatchSession?, isConnected: Bool = true) -> [String: Any] {
        guard let session, let data = try? JSONEncoder().encode(session) else { return [signedOutKey: true] }
        guard isConnected else { return [notConnectedKey: true] }
        return [sessionKey: data]
    }

    /// What a message from the iPhone says, or `nil` when it is something else.
    public static func update(from message: [String: Any]) -> Update? {
        if let data = message[sessionKey] as? Data, let session = try? JSONDecoder().decode(WatchSession.self, from: data) {
            return .session(session)
        }
        if message[signedOutKey] as? Bool == true { return .signedOut }
        if message[notConnectedKey] as? Bool == true { return .notConnected }
        return nil
    }
}
