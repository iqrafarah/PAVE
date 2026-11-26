import Foundation

/// Where the mail lives. "Mac Mail" has no API of its own: it reads iCloud Mail, so PAVE talks to iCloud directly.
/// PAVE only supports iCloud Mail.
nonisolated enum EmailProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case icloud

    var id: Self { self }

    var title: String {
        switch self {
        case .icloud: "iCloud Mail"
        }
    }

    var subtitle: String {
        switch self {
        case .icloud: "Je @icloud.com-adres, ook in Mail op je Mac"
        }
    }
}

nonisolated struct EmailAddress: Codable, Hashable, Sendable {
    var name: String?
    var address: String

    /// The name if there is one, otherwise the part before the @.
    var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return String(address.split(separator: "@").first ?? Substring(address))
    }

    func matches(_ other: String) -> Bool {
        address.caseInsensitiveCompare(other) == .orderedSame
    }
}

nonisolated struct EmailAccount: Codable, Hashable, Identifiable, Sendable {
    let provider: EmailProvider
    let address: String
    var displayName: String?

    var id: EmailProvider { provider }
}

/// Where a message sits on the provider, so it can be fetched, marked read or replied to later.
nonisolated enum EmailLocation: Hashable, Sendable {
    /// An IMAP folder and the message's UID in it.
    case imap(folder: String, uid: UInt32)
}

nonisolated struct EmailAttachment: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let mimeType: String
    let size: Int
    /// Filled once the whole message is downloaded.
    var data: Data?
}

nonisolated struct EmailMessage: Identifiable, Hashable, Sendable {
    let id: String
    let provider: EmailProvider
    let location: EmailLocation
    var messageID: String?
    var inReplyTo: String?
    var references: [String] = []
    let from: EmailAddress
    var to: [EmailAddress] = []
    var cc: [EmailAddress] = []
    let subject: String
    let date: Date
    var isRead: Bool
    var isFromMe: Bool
    var hasAttachments = false
    /// A newsletter, notification or other mail no person wrote (List-Unsubscribe, no-reply, …).
    var isAutomated = false
    /// Bytes on the server; big ones are not downloaded just for the preview line in Meldingen.
    var size = 0
    /// Only the new part of the message, without the quoted history, so it reads like a chat bubble.
    var body: String?
    /// The HTML of the message, kept when it has formatting the text loses (a table, a list, pictures).
    var html: String?
    var attachments: [EmailAttachment] = []

    var isLoaded: Bool { body != nil }
}

nonisolated struct EmailThread: Identifiable, Hashable, Sendable {
    let id: String
    let provider: EmailProvider
    var messages: [EmailMessage]

    var latest: EmailMessage? { messages.max { $0.date < $1.date } }
    var date: Date { latest?.date ?? .distantPast }
    var unreadCount: Int { messages.filter { !$0.isRead && !$0.isFromMe }.count }
    var isUnread: Bool { unreadCount > 0 }

    /// Without "Re:" and the like; empty when the mail has no subject, and then the screens leave it out, as
    /// Messages does, instead of writing "(geen onderwerp)".
    var subject: String {
        let first = messages.min { $0.date < $1.date }?.subject ?? ""
        return EmailThreading.normalizedSubject(first)
    }

    /// The people you write with, without yourself (also when you mailed yourself, or wrote from another address of yours).
    var participants: [EmailAddress] {
        var seen = Set(messages.filter(\.isFromMe).map { $0.from.address.lowercased() })
        var result: [EmailAddress] = []
        for message in messages.sorted(by: { $0.date > $1.date }) {
            let others = message.isFromMe ? message.to + message.cc : [message.from]
            for person in others where seen.insert(person.address.lowercased()).inserted {
                result.append(person)
            }
        }
        return result
    }

    var participantNames: String {
        let people = Array(participants.prefix(3))
        let names = people.map(\.displayName)
        // Two people with the same name (iqra@gmail.com and iqra@icloud.com): their addresses tell them apart.
        let labels = people.map { person in
            names.filter { $0 == person.displayName }.count > 1 ? person.address : person.displayName
        }
        return labels.isEmpty ? "Jij" : labels.joined(separator: ", ")
    }
}

/// A file you add to a reply.
nonisolated struct EmailOutgoingAttachment: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let mimeType: String
    let data: Data
}

nonisolated enum EmailError: LocalizedError, Equatable, Sendable {
    case wrongPassword
    case expired
    case network
    case server(String)
    case attachmentTooLarge(String)
    /// Not in the bin any more: removed for good, in Mail or by an older version of PAVE.
    case goneForGood

    var errorDescription: String? {
        switch self {
        case .wrongPassword:
            "Het e-mailadres of het app-specifieke wachtwoord klopt niet."
        case .expired:
            "Je toegang tot je e-mail is verlopen. Koppel je account opnieuw."
        case .network:
            "Je e-mail kon niet worden opgehaald. Controleer je internetverbinding en probeer opnieuw."
        case let .server(detail):
            "Er ging iets mis bij je e-mailprovider. \(detail)"
        case let .attachmentTooLarge(name):
            "\(name) is te groot om te versturen. Kies een kleiner bestand."
        case .goneForGood:
            "Dit gesprek staat niet meer in de prullenmand van iCloud. Het is definitief verwijderd en kan niet meer terug."
        }
    }
}

/// One mailbox: a connected iCloud account. Everything is fetched live and kept in memory only.
protocol EmailMailbox: Sendable {
    var account: EmailAccount { get }
    /// The newest messages of the inbox and of sent mail, headers only.
    func recentMessages() async throws -> [EmailMessage]
    /// The messages again, now with their text and attachments.
    func load(_ messages: [EmailMessage]) async throws -> [EmailMessage]
    func attachmentData(_ attachment: EmailAttachment, of message: EmailMessage) async throws -> Data
    func markRead(_ messages: [EmailMessage]) async throws
    /// Moves the messages to the mailbox's own bin, as Mail does; they can be brought back from there.
    func trash(_ messages: [EmailMessage]) async throws
    /// Takes them out of the bin again, back to the folder they came from.
    func restore(_ messages: [EmailTrashedMessage]) async throws
    /// The name shown with your address on mail you send.
    func setSenderName(_ name: String?)
    /// Starts a new conversation.
    func send(to recipients: [EmailAddress], subject: String, text: String, attachments: [EmailOutgoingAttachment]) async throws -> EmailSent
    /// Sends the reply to the people in `recipients`: everyone on the message, or only its sender.
    func reply(
        to message: EmailMessage, recipients: EmailReplyRecipients, text: String, attachments: [EmailOutgoingAttachment]
    ) async throws -> EmailSent
    /// Forgets the credentials on this iPhone.
    func disconnect() async
    /// Returns once new mail may have arrived in the inbox (true), or after a while without news (false).
    func waitForNewMail() async throws -> Bool
}

extension EmailMailbox {
    /// For mailboxes that cannot be told: just a pause.
    func waitForNewMail() async throws -> Bool {
        try await Task.sleep(for: .seconds(120))
        return false
    }
}

/// What happened to a sent message: its Message-ID, to recognise the copy in Verzonden, and whether that copy was made.
nonisolated struct EmailSent: Equatable, Sendable {
    var messageID: String?
    var isInSent = true
    /// Why the copy in Verzonden failed, in the server's words.
    var sentProblem: String?
}

extension EmailOutgoingAttachment {
    /// iCloud allows about 20 MB per message, and base64 makes files a third bigger.
    static let maxTotalSize = 15 * 1024 * 1024
}

/// Pins, muting and locks are kept by conversation id, which is that of its first message and can move on when an
/// older message turns up. Any of its messages' ids keeps the mark.
nonisolated enum EmailThreadMarks {
    static func keys(of thread: EmailThread) -> Set<String> {
        Set([thread.id] + thread.messages.compactMap { message in
            message.messageID.map { "\(thread.provider.rawValue):\(EmailThreading.normalizedID($0))" }
        })
    }

    static func contains(_ ids: [String], _ thread: EmailThread) -> Bool {
        guard !ids.isEmpty else { return false }
        return !keys(of: thread).isDisjoint(with: ids)
    }
}
