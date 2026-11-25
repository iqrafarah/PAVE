import Foundation
import PAVECore
import Security
import WidgetKit

/// What the "Mijn sollicitaties" widget shows: the applications still open, how close their deadline is and how often
/// what you shared for them was looked at. Written to the Keychain item the app and the widgets share, like the theme
/// colour; the widget reads the same keys (ApplicationsWidget in PAVEWidgets).
enum ApplicationWidgetSnapshot {
    struct Snapshot: Codable, Equatable {
        struct Row: Codable, Equatable {
            var company: String
            var title: String
            var status: String
            var deadlineDays: Int?
            var looks: Int?
        }
        var rows: [Row]
        var updatedAt: Date
    }

    static let service = "nl.fontys.pave.applications"
    static let account = "snapshot"
    static let widgetKind = "ApplicationsWidget"

    private static var drafts: [ApplicationDraft]?
    private static var shares: [ProfileShare] = []

    static func update(drafts: [ApplicationDraft]) {
        self.drafts = drafts
        publish()
    }

    static func update(shares: [ProfileShare]) {
        self.shares = shares
        if drafts == nil { drafts = ApplicationStore().all() }
        publish()
    }

    /// Open applications first by deadline, then the newest; at most four.
    static func snapshot(drafts: [ApplicationDraft], shares: [ProfileShare], now: Date = .now) -> Snapshot {
        let open = drafts.filter { ![.rejected, .offer].contains($0.progress.status) }
        let rows = open.map { draft -> (Snapshot.Row, Date?) in
            let deadline = draft.progress.status == .concept ? draft.progress.deadline : nil
            let days: Int? = deadline.map {
                switch ApplicationDeadline.of($0, now: now) {
                case .overdue(let days): -days
                case .today: 0
                case .upcoming(let days): days
                }
            }
            let share = shares.first { $0.content.vacancyID == draft.vacancy.id && $0.isLive(at: now) }
            return (Snapshot.Row(company: draft.vacancy.company, title: draft.vacancy.title, status: ApplyMessages.status(draft.progress.status), deadlineDays: days, looks: share?.looks.count), deadline)
        }
        .sorted { a, b in
            switch (a.1, b.1) {
            case let (x?, y?): x < y
            case (.some, .none): true
            case (.none, .some): false
            default: false
            }
        }
        .map(\.0)
        return Snapshot(rows: Array(rows.prefix(4)), updatedAt: now)
    }

    private static func publish() {
        guard let drafts, let group = Bundle.main.object(forInfoDictionaryKey: "PaveKeychainGroup") as? String,
              let data = try? JSONEncoder().encode(snapshot(drafts: drafts, shares: shares)) else { return }
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: group,
        ]
        SecItemDelete(item as CFDictionary)
        var added = item
        added[kSecValueData as String] = data
        added[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(added as CFDictionary, nil) == errSecSuccess else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
