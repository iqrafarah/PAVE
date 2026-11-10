import Foundation

/// What you were still typing, per chat, so it is there again when you come back to that chat or reopen the app.
/// Only on this device, and gone when you sign out.
final class AylaDrafts {
    static let newConversation = "new"
    private static let key = "aylaDrafts"

    /// Nil keeps the drafts only while the app runs (previews and tests).
    private let defaults: UserDefaults?
    private var drafts: [String: String]

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        drafts = defaults?.dictionary(forKey: Self.key) as? [String: String] ?? [:]
    }

    static var standard: AylaDrafts { AylaDrafts(defaults: .standard) }

    subscript(conversationID: String?) -> String {
        drafts[conversationID ?? Self.newConversation] ?? ""
    }

    func save(_ text: String, for conversationID: String?) {
        let key = conversationID ?? Self.newConversation
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard drafts[key] != (isEmpty ? nil : text) else { return }
        drafts[key] = isEmpty ? nil : text
        defaults?.set(drafts, forKey: Self.key)
    }

    func remove(_ conversationIDs: some Sequence<String>) {
        for id in conversationIDs { drafts[id] = nil }
        defaults?.set(drafts, forKey: Self.key)
    }

    static func forget(in defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}
