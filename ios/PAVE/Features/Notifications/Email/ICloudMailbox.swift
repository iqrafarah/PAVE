import Foundation

/// iCloud Mail, the mail Mail on the Mac reads too. Apple offers no sign-in for other apps here, so it works like any
/// mail program: IMAP to read, SMTP to send, with an app-specific password the student makes at account.apple.com.
final class ICloudMailbox: EmailMailbox {
    static let imapHost = "imap.mail.me.com"
    static let smtpHost = "smtp.mail.me.com"
    static let inbox = "INBOX"
    /// How many of the newest messages are read for the list: the inbox, and more of Verzonden, because that is how
    /// PAVE learns who you write with.
    static let recentInboxCount = 100
    static let recentSentCount = 200

    let account: EmailAccount
    private let password: String
    private let store: EmailCredentialStore
    /// The user name that worked: the whole address, or the part before the @.
    private var loginName: String
    private var sentFolder: String?
    private var senderName: String?

    func setSenderName(_ name: String?) {
        senderName = name?.trimmingCharacters(in: .whitespaces).isEmpty == false ? name : nil
    }

    init(credentials: EmailCredentials, store: EmailCredentialStore = EmailCredentialStore()) {
        account = credentials.account
        password = credentials.secret
        self.store = store
        loginName = credentials.loginName ?? credentials.account.address
    }

    /// Checks the address and password by logging in once, and keeps them only when that works.
    static func connect(address: String, password: String, store: EmailCredentialStore = EmailCredentialStore()) async throws -> ICloudMailbox {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let password = password.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let client = IMAPClient(host: imapHost)
        try await client.open()
        let name = try await login(client, address: address, password: password)
        await client.logout()
        let credentials = EmailCredentials(account: EmailAccount(provider: .icloud, address: address), secret: password, loginName: name)
        try store.save(credentials)
        return ICloudMailbox(credentials: credentials, store: store)
    }

    /// Apple asks for the whole address, though some accounts only take the part before the @.
    private static func login(_ client: IMAPClient, address: String, password: String) async throws -> String {
        do {
            try await client.login(user: address, password: password)
            return address
        } catch EmailError.wrongPassword {
            let name = String(address.split(separator: "@").first ?? "")
            guard !name.isEmpty, name != address else { throw EmailError.wrongPassword }
            try await client.login(user: name, password: password)
            return name
        }
    }

    private func session<T>(_ work: (IMAPClient) async throws -> T) async throws -> T {
        let client = IMAPClient(host: Self.imapHost)
        do {
            try await client.open()
            try await client.login(user: loginName, password: password)
            let result = try await work(client)
            await client.logout()
            return result
        } catch let error as EmailError {
            await client.logout()
            throw error == .wrongPassword ? .expired : error
        } catch let error as IMAPClient.CommandError {
            await client.logout()
            throw EmailError.server(error.text)
        }
    }

    /// iCloud's own name for Verzonden, tried directly when the folder list does not point it out.
    static let sentFolderNames = ["Sent Messages", "Sent", "Verzonden", "Sent Items"]

    private func findSentFolder(_ client: IMAPClient) async throws -> String? {
        if let sentFolder { return sentFolder }
        let folders = (try? await client.folders()) ?? []
        EmailLog.logger.debug("Folders: \(folders.map { "\($0.name) \($0.flags)" }.joined(separator: ", "), privacy: .public)")
        var found = folders.first { $0.flags.contains { $0.caseInsensitiveCompare("\\Sent") == .orderedSame } }?.name
            ?? folders.first { name in Self.sentFolderNames.contains { $0.caseInsensitiveCompare(name.name) == .orderedSame } }?.name
        if found == nil {
            // The list said nothing useful: open the usual names one by one; the first that exists is Verzonden.
            for name in Self.sentFolderNames where (try? await client.open(name, readOnly: true)) != nil {
                found = name
                break
            }
        }
        sentFolder = found
        return found
    }

    // MARK: EmailMailbox

    func recentMessages() async throws -> [EmailMessage] {
        try await session { client in
            var messages: [EmailMessage] = []
            let sent = try await findSentFolder(client)
            for folder in [Self.inbox, sent].compactMap({ $0 }) {
                let count = try await client.open(folder, readOnly: true)
                guard count > 0 else { continue }
                let first = max(1, count - (folder == sent ? Self.recentSentCount : Self.recentInboxCount) + 1)
                let rows = try await client.fetch(
                    "\(first):\(count)",
                    items: "(UID FLAGS INTERNALDATE RFC822.SIZE BODY.PEEK[HEADER.FIELDS (FROM TO CC SUBJECT DATE MESSAGE-ID IN-REPLY-TO REFERENCES CONTENT-TYPE LIST-UNSUBSCRIBE LIST-ID PRECEDENCE AUTO-SUBMITTED)])",
                    byUID: false
                )
                messages += rows.compactMap { message(from: $0, folder: folder, isSentFolder: folder == sent) }
            }
            return messages
        }
    }

    func load(_ messages: [EmailMessage]) async throws -> [EmailMessage] {
        let missing = messages.filter { !$0.isLoaded }
        guard !missing.isEmpty else { return messages }
        var loaded: [String: EmailMessage] = [:]
        try await session { client in
            for (folder, items) in Dictionary(grouping: missing, by: { Self.folder(of: $0) ?? "" }) where !folder.isEmpty {
                try await client.open(folder, readOnly: true)
                let uids = items.compactMap(Self.uid).map(String.init).joined(separator: ",")
                let rows = try await client.fetch(uids, items: "(UID BODY.PEEK[])", byUID: true)
                for row in rows {
                    guard let uid = row["UID"]?.text.flatMap(UInt32.init), let data = row["BODY"]?.data,
                          var message = items.first(where: { Self.uid($0) == uid }) else { continue }
                    let mime = MIMEMessage(data: data)
                    message.body = EmailThreading.stripQuotedText(mime.bodyText)
                    message.html = mime.bodyHTML.flatMap { EmailHTML.hasFormatting($0) ? $0 : nil }
                    message.attachments = mime.attachments
                    message.hasAttachments = !message.attachments.isEmpty
                    loaded[message.id] = message
                }
            }
        }
        return messages.map { loaded[$0.id] ?? $0 }
    }

    func attachmentData(_ attachment: EmailAttachment, of message: EmailMessage) async throws -> Data {
        if let data = attachment.data { return data }
        // Mail you sent from PAVE that Verzonden has not shown yet: after a restart its local copy only knows the file
        // names, so the file comes from the copy in Verzonden, found by its Message-ID.
        let isLocal = (Self.uid(message) ?? 0) == 0 || (Self.folder(of: message) ?? "").isEmpty
        let attachments = isLocal
            ? try await sentAttachments(of: message)
            : (try await load([message.withoutBody])).first?.attachments ?? []
        let match = attachments.first { $0.id == attachment.id && $0.name == attachment.name }
            ?? attachments.first { $0.name == attachment.name }
        guard let data = match?.data else {
            throw EmailError.server(isLocal
                ? "De bijlage staat nog niet in Verzonden. Probeer het straks opnieuw."
                : "De bijlage is niet meer te vinden.")
        }
        return data
    }

    /// The files of your own message as Verzonden has it; empty when it is not there (yet).
    private func sentAttachments(of message: EmailMessage) async throws -> [EmailAttachment] {
        guard let messageID = message.messageID else { return [] }
        var attachments: [EmailAttachment] = []
        try await session { client in
            guard let sent = try await findSentFolder(client) else { return }
            try await client.open(sent, readOnly: true)
            guard let uid = try await Self.search(messageID, with: client).last else { return }
            let rows = try await client.fetch(uid, items: "(UID BODY.PEEK[])", byUID: true)
            if let data = rows.first?["BODY"]?.data { attachments = MIMEMessage(data: data).attachments }
        }
        return attachments
    }

    func markRead(_ messages: [EmailMessage]) async throws {
        let unread = messages.filter { !$0.isRead }
        guard !unread.isEmpty else { return }
        try await session { client in
            for (folder, items) in Dictionary(grouping: unread, by: { Self.folder(of: $0) ?? "" }) where !folder.isEmpty {
                try await client.open(folder, readOnly: false)
                let uids = items.compactMap(Self.uid).map(String.init).joined(separator: ",")
                try await client.command("UID STORE \(uids) +FLAGS.SILENT (\\Seen)")
            }
        }
    }

    /// iCloud's own name for the bin, tried when the folder list does not point it out.
    static let trashFolderNames = ["Deleted Messages", "Trash", "Prullenmand", "Verwijderde berichten", "Deleted Items"]

    /// Always into a bin, so "Recent verwijderd" can bring it back: a mailbox without one (a new iCloud account that never
    /// deleted anything in Mail) gets iCloud's own "Deleted Messages". Nothing is ever removed without a copy there.
    func trash(_ messages: [EmailMessage]) async throws {
        let onServer = messages.filter { Self.uid($0) != nil && Self.uid($0) != 0 }
        guard !onServer.isEmpty else { return }
        try await session { client in
            var bin = try await findTrashFolder(client)
            if bin == nil, await Self.create(Self.trashFolderNames[0], with: client) { bin = Self.trashFolderNames[0] }
            guard let bin else { throw EmailError.server("Er is geen prullenmand in je mailbox gevonden.") }
            EmailLog.logger.info("Moving \(onServer.count) messages to \(bin, privacy: .public)")
            for (folder, items) in Dictionary(grouping: onServer, by: { Self.folder(of: $0) ?? "" }) where !folder.isEmpty && folder != bin {
                try await client.open(folder, readOnly: false)
                let uids = items.compactMap(Self.uid).map(String.init).joined(separator: ",")
                // MOVE where the server has it; otherwise copy, mark deleted and clear only these messages.
                if (try? await client.command("UID MOVE \(uids) \(IMAPClient.quote(bin))")) == nil {
                    try await client.command("UID COPY \(uids) \(IMAPClient.quote(bin))")
                    try await client.command("UID STORE \(uids) +FLAGS.SILENT (\\Deleted)")
                    _ = try? await client.command("UID EXPUNGE \(uids)")
                }
            }
        }
    }

    func restore(_ messages: [EmailTrashedMessage]) async throws {
        guard !messages.isEmpty else { return }
        try await session { client in
            guard let bin = try await findTrashFolder(client) else { throw EmailError.server("De prullenmand is niet gevonden.") }
            try await client.open(bin, readOnly: false)
            var restored = 0
            for (folder, items) in Dictionary(grouping: messages, by: \.folder) {
                var uids: [String] = []
                for item in items {
                    uids += try await Self.search(item.messageID, with: client)
                }
                EmailLog.logger.info("Found \(uids.count) of \(items.count) messages in \(bin, privacy: .public)")
                guard !uids.isEmpty else { continue }
                restored += uids.count
                // Verzonden may be missing now too; then it comes back.
                if (try? await client.command("EXAMINE \(IMAPClient.quote(folder))")) == nil { _ = await Self.create(folder, with: client) }
                try await client.open(bin, readOnly: false)
                let set = uids.joined(separator: ",")
                if (try? await client.command("UID MOVE \(set) \(IMAPClient.quote(folder))")) == nil {
                    try await client.command("UID COPY \(set) \(IMAPClient.quote(folder))")
                    try await client.command("UID STORE \(set) +FLAGS.SILENT (\\Deleted)")
                    _ = try? await client.command("UID EXPUNGE \(set)")
                }
            }
            guard restored > 0 else { throw EmailError.goneForGood }
        }
    }

    /// The UIDs of a message in the open folder, by its Message-ID; some servers only find it without the < >.
    private static func search(_ messageID: String, with client: IMAPClient) async throws -> [String] {
        let id = messageID.replacingOccurrences(of: "\"", with: "")
        let bare = id.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        for query in [id, bare] where !query.isEmpty {
            let found = try await client.command("UID SEARCH HEADER Message-ID \(IMAPClient.quote(query))")
            let uids = found.flatMap { response -> [String] in
                let values = response.values
                guard values.count > 2, values[1].text?.uppercased() == "SEARCH" else { return [] }
                return values.dropFirst(2).compactMap(\.text)
            }
            if !uids.isEmpty { return uids }
        }
        return []
    }

    /// Makes a folder; true when it is there afterwards, also when it already was.
    private static func create(_ name: String, with client: IMAPClient) async -> Bool {
        if (try? await client.command("CREATE \(IMAPClient.quote(name))")) != nil {
            EmailLog.logger.info("Created the folder \(name, privacy: .public)")
            return true
        }
        return (try? await client.open(name, readOnly: true)) != nil
    }

    private func findTrashFolder(_ client: IMAPClient) async throws -> String? {
        let folders = (try? await client.folders()) ?? []
        if let found = folders.first(where: { $0.flags.contains { $0.caseInsensitiveCompare("\\Trash") == .orderedSame } })?.name
            ?? folders.first(where: { folder in Self.trashFolderNames.contains { $0.caseInsensitiveCompare(folder.name) == .orderedSame } })?.name {
            return found
        }
        for name in Self.trashFolderNames where (try? await client.open(name, readOnly: true)) != nil { return name }
        return nil
    }

    func send(to recipients: [EmailAddress], subject: String, text: String, attachments: [EmailOutgoingAttachment]) async throws -> EmailSent {
        let me = EmailAddress(name: senderName, address: account.address)
        let (data, messageID) = MIMEBuilder.reply(
            from: me, to: recipients, cc: [], subject: subject, text: text, quoting: nil, attachments: attachments
        )
        let problem = try await deliver(data, messageID: messageID, to: recipients)
        return EmailSent(messageID: messageID, isInSent: problem == nil, sentProblem: problem)
    }

    func reply(
        to message: EmailMessage, recipients: EmailReplyRecipients, text: String, attachments: [EmailOutgoingAttachment]
    ) async throws -> EmailSent {
        let me = EmailAddress(name: senderName, address: account.address)
        let subject = EmailReplyRecipients.replySubject(message.subject)
        let (data, messageID) = MIMEBuilder.reply(
            from: me, to: recipients.to, cc: recipients.cc, subject: subject, text: text,
            quoting: message, attachments: attachments
        )
        let problem = try await deliver(data, messageID: messageID, to: recipients.to + recipients.cc)
        return EmailSent(messageID: messageID, isInSent: problem == nil, sentProblem: problem)
    }

    /// Sends over SMTP, then puts a copy in Verzonden; returns why that copy failed, or nil when it worked.
    private func deliver(_ data: Data, messageID: String, to recipients: [EmailAddress]) async throws -> String? {
        do {
            try await SMTPClient(host: Self.smtpHost).send(
                data, from: account.address, to: recipients.map(\.address),
                user: account.address, password: password
            )
        } catch let error as SMTPClient.ReplyError {
            EmailLog.logger.error("SMTP refused the message: \(error.code) \(error.text, privacy: .public)")
            throw EmailError.server(error.text)
        }
        EmailLog.logger.info("SMTP accepted the message \(messageID, privacy: .private)")
        // Mail on the Mac puts a copy in Verzonden itself; over SMTP that is up to the app. Not worth failing the send over.
        do {
            return try await session { client in
                var sent = try await findSentFolder(client)
                // A new iCloud account has no Verzonden until Mail first sends: it gets iCloud's own name for it.
                if sent == nil, await Self.create(Self.sentFolderNames[0], with: client) {
                    sent = Self.sentFolderNames[0]
                    sentFolder = sent
                }
                guard let sent else {
                    EmailLog.logger.error("No Verzonden folder found in the mailbox")
                    return "geen map Verzonden gevonden"
                }
                try await client.append(data, to: sent)
                EmailLog.logger.info("Added the message to \(sent, privacy: .public)")
                return nil
            }
        } catch let error as EmailError {
            EmailLog.logger.error("Could not add the message to Verzonden: \(String(describing: error), privacy: .public)")
            if case let .server(detail) = error { return detail }
            return error.errorDescription
        } catch {
            EmailLog.logger.error("Could not add the message to Verzonden: \(String(describing: error), privacy: .public)")
            return String(describing: error)
        }
    }

    func disconnect() async {
        store.delete(.icloud)
    }

    /// IMAP IDLE on the inbox: iCloud says it the moment mail arrives. A read error after the long wait just means
    /// nothing came; the caller waits again.
    func waitForNewMail() async throws -> Bool {
        let client = IMAPClient(host: Self.imapHost)
        return try await withTaskCancellationHandler {
            try await client.open()
            try await client.login(user: loginName, password: password)
            try await client.open(Self.inbox, readOnly: true)
            let arrived = try await client.idle(for: 20 * 60)
            await client.logout()
            return arrived
        } onCancel: {
            Task { @MainActor in client.close() }
        }
    }

    // MARK: Reading a FETCH row

    private func message(from row: [String: IMAPValue], folder: String, isSentFolder: Bool) -> EmailMessage? {
        guard let uid = row["UID"]?.text.flatMap(UInt32.init), let headers = row["BODY"]?.data else { return nil }
        let mime = MIMEMessage(data: headers)
        let flags = row["FLAGS"]?.items.compactMap(\.text).map { $0.lowercased() } ?? []
        let from = mime.from ?? EmailAddress(name: nil, address: account.address)
        let internalDate = row["INTERNALDATE"]?.text.flatMap(Self.internalDate)
        let isFromMe = isSentFolder || from.matches(account.address)
        let contentType = mime.root.contentType
        return EmailMessage(
            id: "icloud:\(folder):\(uid)",
            provider: .icloud,
            location: .imap(folder: folder, uid: uid),
            messageID: mime.messageID,
            inReplyTo: mime.inReplyTo,
            references: mime.references,
            from: from,
            to: mime.to,
            cc: mime.cc,
            subject: mime.subject,
            date: mime.date ?? internalDate ?? .distantPast,
            isRead: isFromMe || flags.contains("\\seen"),
            isFromMe: isFromMe,
            hasAttachments: contentType.type == "multipart" && contentType.subtype == "mixed",
            isAutomated: !isFromMe && mime.isAutomated,
            size: row["RFC822.SIZE"]?.text.flatMap(Int.init) ?? 0
        )
    }

    private static func folder(of message: EmailMessage) -> String? {
        if case let .imap(folder, _) = message.location { folder } else { nil }
    }

    private static func uid(_ message: EmailMessage) -> UInt32? {
        if case let .imap(_, uid) = message.location { uid } else { nil }
    }

    /// "24-Nov-2026 09:12:03 +0100".
    private static func internalDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d-MMM-yyyy HH:mm:ss Z"
        return formatter.date(from: value.trimmingCharacters(in: .whitespaces))
    }
}

/// Who a reply goes to: everyone who was on the message, minus yourself, or only the person who wrote it.
nonisolated struct EmailReplyRecipients: Equatable, Sendable {
    var to: [EmailAddress]
    var cc: [EmailAddress]

    var everyone: [EmailAddress] { to + cc }

    /// "Antwoord": only the sender. Your own message goes back to the first person you wrote to.
    init(onlySenderOf message: EmailMessage, as me: String) {
        let person = message.isFromMe ? message.to.first { !$0.matches(me) } : message.from
        to = person.map { [$0] } ?? []
        cc = []
    }

    init(replyingTo message: EmailMessage, as me: String) {
        func unique(_ people: [EmailAddress], excluding: Set<String>) -> [EmailAddress] {
            var seen = excluding
            return people.filter { seen.insert($0.address.lowercased()).inserted }
        }
        let mine: Set<String> = [me.lowercased()]
        if message.isFromMe {
            to = unique(message.to, excluding: mine)
            cc = unique(message.cc, excluding: mine.union(to.map { $0.address.lowercased() }))
        } else {
            to = unique([message.from] + message.to, excluding: mine)
            cc = unique(message.cc, excluding: mine.union(to.map { $0.address.lowercased() }))
        }
    }

    static func replySubject(_ subject: String) -> String {
        let clean = EmailThreading.normalizedSubject(subject)
        return clean.isEmpty ? "Re:" : "Re: \(clean)"
    }
}

extension EmailMessage {
    nonisolated var withoutBody: EmailMessage {
        var copy = self
        copy.body = nil
        copy.attachments = []
        return copy
    }
}
