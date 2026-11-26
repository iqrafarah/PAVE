import Foundation

/// What the iPhone tells the Watch as it happens, for a tap on the wrist: someone opened what you shared, an employer
/// at the fair invites you, a stand you scanned, something Ayla set up on the iPhone, and how far your plan is. Only
/// short lines go over: never evidence, files or messages.
public enum WatchEvent: Codable, Equatable, Sendable {
    /// Someone opened what you shared.
    case look(who: String, what: String)
    /// An employer at the fair invites you; you answer Ja or Nee on the wrist.
    case invitation(id: String, employer: String, vacancy: String, at: Date?)
    /// The stand you just scanned, in one line.
    case standTip(employer: String, line: String)
    /// Something Ayla set up on the iPhone after you asked on the Watch.
    case handoff(title: String, detail: String)
    /// The plan you are on.
    case plan(name: String, done: Int, total: Int, current: String?)

    public static let key = "watchEvent"

    public var data: Data? { try? JSONEncoder().encode(self) }

    public static func from(_ userInfo: [String: Any]) -> WatchEvent? {
        guard let data = userInfo[key] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchEvent.self, from: data)
    }

    /// Whether the wrist taps for it: everything except a quiet update of the plan.
    public var taps: Bool {
        if case .plan = self { return false }
        return true
    }
}

/// What the Watch asks the iPhone to do: answer an invitation, or carry out what Ayla proposed and you said Ja to.
public enum WatchRequest: Codable, Equatable, Sendable {
    case answerInvitation(id: String, accepted: Bool)
    case actions([AylaAppAction])

    public static let key = "watchRequest"

    public var message: [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return [Self.key: data]
    }

    public static func from(_ message: [String: Any]) -> WatchRequest? {
        guard let data = message[key] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchRequest.self, from: data)
    }
}
