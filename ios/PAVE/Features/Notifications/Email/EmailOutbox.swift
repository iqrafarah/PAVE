import Foundation

/// Mail you sent from PAVE, kept on this iPhone until its copy shows up in Verzonden, so it does not vanish when the
/// app restarts before that. Only text and file names; the files themselves are not kept.
nonisolated struct EmailOutbox: Sendable {
    struct Entry: Codable, Equatable, Sendable {
        let messageID: String
        let threadID: String
        let from: EmailAddress
        let to: [EmailAddress]
        let cc: [EmailAddress]
        let subject: String
        let body: String
        let date: Date
        let attachments: [File]
        /// What it answers, so a restart keeps it in the right conversation. Optional for entries saved before.
        var inReplyTo: String?
        var references: [String]?

        struct File: Codable, Equatable, Sendable {
            let name: String
            let mimeType: String
            let size: Int
        }
    }

    /// How long a message waits for its copy in Verzonden before PAVE stops showing it.
    static let keepDays = 7

    let url: URL

    static var standard: EmailOutbox {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Email", directoryHint: .isDirectory)
        return EmailOutbox(url: folder.appending(path: "outbox.json"))
    }

    func load() -> [Entry] {
        guard let data = try? Data(contentsOf: url), let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        let limit = Date.now.addingTimeInterval(-Double(Self.keepDays) * 86_400)
        return entries.filter { $0.date > limit }
    }

    func save(_ entries: [Entry]) {
        guard !entries.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(entries).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

extension EmailOutbox.Entry {
    nonisolated init(threadID: String, message: EmailMessage) {
        self.init(
            messageID: message.messageID ?? message.id,
            threadID: threadID,
            from: message.from,
            to: message.to,
            cc: message.cc,
            subject: message.subject,
            body: message.body ?? "",
            date: message.date,
            attachments: message.attachments.map { File(name: $0.name, mimeType: $0.mimeType, size: $0.size) },
            inReplyTo: message.inReplyTo,
            references: message.references
        )
    }

    nonisolated var message: EmailMessage {
        EmailMessage(
            id: "local:\(messageID)",
            provider: .icloud,
            location: .imap(folder: "", uid: 0),
            messageID: messageID,
            inReplyTo: inReplyTo,
            references: references ?? [],
            from: from,
            to: to,
            cc: cc,
            subject: subject,
            date: date,
            isRead: true,
            isFromMe: true,
            hasAttachments: !attachments.isEmpty,
            body: body,
            attachments: attachments.enumerated().map { index, file in
                EmailAttachment(id: "\(index)", name: file.name, mimeType: file.mimeType, size: file.size)
            }
        )
    }
}
