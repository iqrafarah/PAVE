import Foundation

/// A place where the account is signed in: one session, described from the browser or app that started it.
public struct SignedInDevice: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case iPhone
        case iPad
        case mac
        case windows
        case android
        case linux
        case unknown
    }

    public enum Client: Equatable, Sendable {
        /// The PAVE app for iPhone and iPad.
        case paveApp
        case browser(String)
        case unknown
    }

    public let id: String
    public let kind: Kind
    public let client: Client
    public let signedInAt: Date
    public let lastActiveAt: Date
    /// The device this list is shown on.
    public let isCurrent: Bool

    public init(id: String, kind: Kind, client: Client, signedInAt: Date, lastActiveAt: Date, isCurrent: Bool) {
        self.id = id
        self.kind = kind
        self.client = client
        self.signedInAt = signedInAt
        self.lastActiveAt = lastActiveAt
        self.isCurrent = isCurrent
    }

    public init(id: String, userAgent: String?, signedInAt: Date, lastActiveAt: Date, isCurrent: Bool) {
        let (kind, client) = Self.describe(userAgent: userAgent ?? "")
        self.init(id: id, kind: kind, client: client, signedInAt: signedInAt, lastActiveAt: lastActiveAt, isCurrent: isCurrent)
    }

    /// The PAVE app sends "PAVE-iOS/0.1 (iPhone; iOS 26.1)"; older versions only the system's "PAVE/1 CFNetwork/…".
    /// Browsers are told apart by their usual names, with Edge and Opera before Chrome and Chrome before Safari.
    public static func describe(userAgent: String) -> (Kind, Client) {
        if userAgent.hasPrefix("PAVE-iOS/") {
            return (userAgent.contains("iPad") ? .iPad : .iPhone, .paveApp)
        }
        if userAgent.contains("CFNetwork") {
            return (.unknown, .paveApp)
        }
        let kind: Kind =
            if userAgent.contains("iPhone") { .iPhone }
            else if userAgent.contains("iPad") { .iPad }
            else if userAgent.contains("Android") { .android }
            else if userAgent.contains("Macintosh") || userAgent.contains("Mac OS X") { .mac }
            else if userAgent.contains("Windows") { .windows }
            else if userAgent.contains("Linux") { .linux }
            else { .unknown }
        let browser: String? =
            if userAgent.contains("Edg") { "Edge" }
            else if userAgent.contains("OPR/") { "Opera" }
            else if userAgent.contains("Firefox/") || userAgent.contains("FxiOS") { "Firefox" }
            else if userAgent.contains("Chrome/") || userAgent.contains("CriOS") { "Chrome" }
            else if userAgent.contains("Safari/") { "Safari" }
            else { nil }
        return (kind, browser.map(Client.browser) ?? .unknown)
    }

    /// What the PAVE app sends as its User-Agent, so this list can name it.
    public static func appUserAgent(version: String, model: String, systemVersion: String) -> String {
        "PAVE-iOS/\(version) (\(model); iOS \(systemVersion))"
    }
}
