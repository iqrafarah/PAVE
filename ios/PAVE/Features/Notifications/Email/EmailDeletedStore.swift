import Foundation

/// A message in the bin, found again by its Message-ID, and the folder it came from.
nonisolated struct EmailTrashedMessage: Codable, Hashable, Sendable {
    let messageID: String
    let folder: String
}

/// A conversation you deleted, for "Recent verwijderd": enough to show it and to put it back for a week.
nonisolated struct EmailDeletedThread: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let subject: String
    let people: [EmailAddress]
    let date: Date
    let deletedAt: Date
    let messages: [EmailTrashedMessage]
    /// Sent from PAVE but never in Verzonden: kept whole, since the mailbox has no copy to bring back.
    var localMessages: [EmailOutbox.Entry]?
}

/// Kept on this iPhone only, like the outbox.
nonisolated struct EmailDeletedStore: Sendable {
    let url: URL

    static var standard: EmailDeletedStore {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Email", directoryHint: .isDirectory)
        return EmailDeletedStore(url: folder.appending(path: "deleted.json"))
    }

    func load() -> [EmailDeletedThread] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([EmailDeletedThread].self, from: data) else { return [] }
        // A week, as for meldingen (PaveNotification.restorableDays).
        let limit = Date.now.addingTimeInterval(-7 * 86_400)
        return entries.filter { $0.deletedAt > limit }
    }

    func save(_ entries: [EmailDeletedThread]) {
        guard !entries.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(entries).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
