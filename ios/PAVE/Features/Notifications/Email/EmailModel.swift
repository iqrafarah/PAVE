import Foundation
import PAVECore
import Observation

/// The connected mailboxes and their conversations, for Meldingen. Mail is fetched live from iCloud and
/// only kept in memory: nothing goes to PAVE's server, and closing the app forgets it.
@MainActor @Observable
final class EmailModel {
    private(set) var accounts: [EmailAccount] = []
    private(set) var threads: [EmailThread] = []
    private(set) var problem: String?
    private(set) var isRefreshing = false
    /// New mail that arrived while PAVE was open, for the banner at the top.
    private(set) var banner: PaveNotification?

    @ObservationIgnored private var mailboxes: [EmailProvider: any EmailMailbox] = [:]
    @ObservationIgnored private let store: EmailCredentialStore
    /// Messages already opened, with their text and attachments, so a refresh does not throw them away.
    @ObservationIgnored private var loaded: [String: EmailMessage] = [:]
    /// What the last refresh found that was new, for a melding on the lock screen when PAVE is in the background.
    @ObservationIgnored private(set) var arrivals: [PaveNotification] = []
    /// Replies you sent, by Message-ID, until their copy shows up in Verzonden; otherwise a refresh would hide them.
    @ObservationIgnored private var pendingSent: [String: (threadID: String, message: EmailMessage)] = [:] {
        didSet { outbox?.save(pendingSent.values.map { EmailOutbox.Entry(threadID: $0.threadID, message: $0.message) }) }
    }
    /// The same, on disk, so a restart before Verzonden has the copy does not lose what you sent.
    @ObservationIgnored private let outbox: EmailOutbox?
    @ObservationIgnored private let deletedStore: EmailDeletedStore?

    /// Conversations you deleted in the past week, for "Recent verwijderd".
    private(set) var recentlyDeleted: [EmailDeletedThread] = [] {
        didSet { deletedStore?.save(recentlyDeleted) }
    }
    /// The people you write with (from Verzonden) and, when allowed, the addresses in your contacts.
    private var knownPeople: Set<String> = []

    /// Your name in PAVE, as the sender of your mail ("Ravi <ravi@icloud.com>" lands in spam less than a bare address).
    var senderName: String? {
        didSet { mailboxes.values.forEach { $0.setSenderName(senderName) } }
    }

    /// The conversations Meldingen shows: only with people you know, without newsletters and automatic mail, and not
    /// the ones you are deleting right now.
    var visibleThreads: [EmailThread] {
        threads.filter { !deletingThreadIDs.contains($0.id) && EmailThreading.isConversation($0, known: knownPeople) }
    }

    // MARK: Deleting

    /// How long "Ongedaan maken" stays before the conversation really goes to the bin.
    static let undoSeconds: Double = 5

    /// Conversations you just deleted, hidden while you can still undo it.
    private(set) var deletingThreadIDs: Set<String> = []
    @ObservationIgnored private var deletions: [String: Task<Void, Never>] = [:]

    /// Hides the conversation at once and moves it to the bin once "Ongedaan maken" is gone.
    func delete(_ threadID: String) {
        guard let thread = thread(threadID) else { return }
        deletingThreadIDs.insert(threadID)
        deletions[threadID]?.cancel()
        deletions[threadID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.undoSeconds))
            guard !Task.isCancelled, let self else { return }
            await self.moveToBin(thread.messages, removing: threadID)
        }
    }

    /// Every deleted conversation goes to "Recent verwijderd": what is in the mailbox by where it was, and what only
    /// lived on this iPhone (sent, not yet in Verzonden) as it was.
    private func remember(_ thread: EmailThread) {
        var onServer: [EmailTrashedMessage] = []
        var local: [EmailOutbox.Entry] = []
        for message in thread.messages {
            if case let .imap(folder, uid) = message.location, uid != 0, !folder.isEmpty, let id = message.messageID {
                onServer.append(EmailTrashedMessage(messageID: id, folder: folder))
            } else if message.isFromMe {
                local.append(EmailOutbox.Entry(threadID: thread.id, message: message))
            }
        }
        recentlyDeleted.removeAll { $0.id == thread.id }
        recentlyDeleted.insert(EmailDeletedThread(
            id: thread.id, subject: thread.subject, people: thread.participants, date: thread.date, deletedAt: .now,
            messages: onServer, localMessages: local
        ), at: 0)
    }

    /// "Terugzetten" in Recent verwijderd: out of the bin, back where it was, and into the list again.
    /// Why the last "Terugzetten" failed, for the message in Recent verwijderd (not the bar above Meldingen).
    private(set) var restoreProblem: String?

    func restore(_ threadID: String) async -> Bool {
        restoreProblem = nil
        guard let deleted = recentlyDeleted.first(where: { $0.id == threadID }), let mailbox = mailboxes[.icloud] else { return false }
        do {
            try await mailbox.restore(deleted.messages)
            for entry in deleted.localMessages ?? [] { pendingSent[entry.messageID] = (entry.threadID, entry.message) }
            recentlyDeleted.removeAll { $0.id == threadID }
            await refreshAfterChange()
            return true
        } catch EmailError.goneForGood {
            // Nothing left to bring back, so it leaves the list too.
            recentlyDeleted.removeAll { $0.id == threadID }
            restoreProblem = EmailError.goneForGood.errorDescription
            return false
        } catch {
            restoreProblem = (error as? LocalizedError)?.errorDescription ?? EmailError.network.errorDescription
            return false
        }
    }

    func undoDelete(_ threadID: String) {
        deletions[threadID]?.cancel()
        deletions[threadID] = nil
        deletingThreadIDs.remove(threadID)
    }

    /// One message: straight to the bin (the conversation asks first).
    func delete(_ message: EmailMessage, in threadID: String) async {
        await moveToBin([message], removing: nil)
        update(threadID) { $0.messages.removeAll { $0.id == message.id } }
        if thread(threadID)?.messages.isEmpty == true { threads.removeAll { $0.id == threadID } }
    }

    private func moveToBin(_ messages: [EmailMessage], removing threadID: String?) async {
        // What only exists on this iPhone (sent, not yet in Verzonden) just goes.
        for message in messages {
            if let id = message.messageID { pendingSent[id] = nil }
        }
        let provider = messages.first?.provider ?? .icloud
        do {
            // Only what the mailbox has; the rest was only ever on this iPhone.
            let onServer = messages.filter { if case let .imap(_, uid) = $0.location { uid != 0 } else { true } }
            if !onServer.isEmpty { try await mailboxes[provider]?.trash(onServer) }
            problem = nil
            if let threadID, let thread = thread(threadID) {
                if isPinned(thread) { togglePin(threadID) }
                remember(thread)
                threads.removeAll { $0.id == threadID }
            }
            for message in messages { loaded[message.id] = nil }
        } catch {
            problem = Self.describe(error, provider: provider)
        }
        if let threadID {
            deletingThreadIDs.remove(threadID)
            deletions[threadID] = nil
        }
    }

    // MARK: Pinned

    static let pinnedKey = "emailPinnedThreads"
    /// As in Messages: at most nine conversations at the top.
    static let maxPinned = 9

    /// Conversations you pinned, in the order you pinned them. Kept on this iPhone only.
    private(set) var pinnedIDs: [String] = UserDefaults.standard.stringArray(forKey: EmailModel.pinnedKey) ?? [] {
        didSet { UserDefaults.standard.set(pinnedIDs, forKey: Self.pinnedKey) }
    }

    /// A conversation keeps its pin when its id moves on: the id is that of its first message, which can change.
    func isPinned(_ thread: EmailThread) -> Bool {
        EmailThreadMarks.contains(pinnedIDs, thread)
    }

    var pinnedThreads: [EmailThread] {
        let pinned = visibleThreads.filter { isPinned($0) && !isLocked($0) }
        return pinned.sorted { a, b in
            (pinnedIDs.firstIndex { pinnedID(of: a) == $0 } ?? .max) < (pinnedIDs.firstIndex { pinnedID(of: b) == $0 } ?? .max)
        }
    }

    var canPinMore: Bool { pinnedThreads.count < Self.maxPinned }

    func togglePin(_ threadID: String) {
        guard let thread = thread(threadID) else { return }
        if isPinned(thread) {
            let ids = EmailThreadMarks.keys(of: thread)
            pinnedIDs.removeAll { ids.contains($0) }
        } else if canPinMore, !isLocked(thread) {
            pinnedIDs.append(thread.id)
        }
    }

    /// Only ever unpins: a second tap on an already unpinned conversation must not pin it again.
    func unpin(_ threadID: String) {
        guard let thread = thread(threadID), isPinned(thread) else { return }
        togglePin(threadID)
    }

    private func pinnedID(of thread: EmailThread) -> String? {
        if pinnedIDs.contains(thread.id) { return thread.id }
        return thread.messages.compactMap { $0.messageID.map { "\(thread.provider.rawValue):\(EmailThreading.normalizedID($0))" } }
            .first { pinnedIDs.contains($0) }
    }

    // MARK: Muted

    static let mutedKey = "emailMutedThreads"

    /// "Dempen": the conversation stays in the list and counts as unread, but no banner comes for it.
    private(set) var mutedIDs: [String] = UserDefaults.standard.stringArray(forKey: EmailModel.mutedKey) ?? [] {
        didSet { UserDefaults.standard.set(mutedIDs, forKey: Self.mutedKey) }
    }

    func isMuted(_ thread: EmailThread) -> Bool {
        EmailThreadMarks.contains(mutedIDs, thread)
    }

    func toggleMute(_ threadID: String) {
        guard let thread = thread(threadID) else { return }
        if isMuted(thread) {
            let ids = EmailThreadMarks.keys(of: thread)
            mutedIDs.removeAll { ids.contains($0) }
        } else {
            mutedIDs.append(thread.id)
            if banner?.emailThreadID == threadID { banner = nil }
        }
    }

    // MARK: Locked

    static let lockedKey = "emailLockedThreads"

    /// "Vergrendelen": the conversation needs your PIN, the same as for locked chats. In the list it shows no names,
    /// subject or text, and search and banners leave it out.
    private(set) var lockedIDs: [String] = UserDefaults.standard.stringArray(forKey: EmailModel.lockedKey) ?? [] {
        didSet { UserDefaults.standard.set(lockedIDs, forKey: Self.lockedKey) }
    }

    /// True after the right PIN, until PAVE goes to the background or you lock again.
    var showsLocked = false

    func isLocked(_ thread: EmailThread) -> Bool {
        EmailThreadMarks.contains(lockedIDs, thread)
    }

    /// Locked and not opened with the PIN yet: nothing of it may show.
    func isHidden(_ thread: EmailThread) -> Bool {
        isLocked(thread) && !showsLocked
    }

    func setLocked(_ isLocked: Bool, _ threadID: String) {
        guard let thread = thread(threadID) else { return }
        if isLocked {
            guard !self.isLocked(thread) else { return }
            unpin(threadID)
            lockedIDs.append(thread.id)
            if banner?.emailThreadID == threadID { banner = nil }
        } else {
            let ids = EmailThreadMarks.keys(of: thread)
            lockedIDs.removeAll { ids.contains($0) }
        }
    }

    /// Every conversation with this person, newest first.
    func threads(with address: String) -> [EmailThread] {
        visibleThreads.filter { thread in !isHidden(thread) && thread.participants.contains { $0.matches(address) } }
    }

    init(store: EmailCredentialStore = EmailCredentialStore()) {
        self.store = store
        outbox = .standard
        deletedStore = .standard
        recentlyDeleted = EmailDeletedStore.standard.load()
        for credentials in store.loadAll() {
            add(ICloudMailbox(credentials: credentials, store: store))
        }
        restoreOutbox()
    }

    private func restoreOutbox() {
        guard let outbox else { return }
        let entries = outbox.load()
        pendingSent = Dictionary(entries.map { ($0.messageID, ($0.threadID, $0.message)) }, uniquingKeysWith: { first, _ in first })
    }

    /// For previews and tests: a mailbox that is not real.
    init(mailboxes: [any EmailMailbox]) {
        store = EmailCredentialStore(service: "nl.fontys.pave.email.preview")
        outbox = nil
        deletedStore = nil
        mailboxes.forEach(add)
    }

    var hasAccounts: Bool { !accounts.isEmpty }

    /// Conversations with mail you have not read yet: what the bell and the app icon count.
    var unreadCount: Int { visibleThreads.filter(\.isUnread).count }

    func thread(_ id: String) -> EmailThread? {
        threads.first { $0.id == id }
    }

    func account(for provider: EmailProvider) -> EmailAccount? {
        accounts.first { $0.provider == provider }
    }

    /// Each conversation as a row in Meldingen; pinned ones sit at the top instead (`pinnedThreads`).
    var notifications: [PaveNotification] {
        visibleThreads.filter { !isPinned($0) }.map(notification(for:))
    }

    /// The deleted conversations as meldingen in "Recent verwijderd".
    var deletedNotifications: [PaveNotification] {
        recentlyDeleted.map { thread in
            let names = thread.people.prefix(3).map(\.displayName).joined(separator: ", ")
            // Without a subject the names are the title ("(geen onderwerp)" came from an older version).
            let hasSubject = !thread.subject.isEmpty && thread.subject != "(geen onderwerp)"
            return PaveNotification(
                id: Self.notificationID(thread.id),
                kind: .email,
                title: hasSubject ? thread.subject : names,
                personName: hasSubject ? names : "E-mail",
                date: thread.date,
                isUnread: false,
                deletedAt: thread.deletedAt,
                emailThreadID: thread.id,
                emailPeople: Array(thread.people.prefix(2))
            )
        }
    }

    /// The last message as a line under the subject, as in Messages: "Jij: …" for yours, "Bijlage" for only a file,
    /// "Doorgestuurd bericht" for a forward without a note.
    static func preview(of thread: EmailThread) -> String? {
        guard let last = thread.messages.last else { return nil }
        // A forward reads as what you wrote with it, or as "Doorgestuurd bericht", not as its headers.
        let (note, isForwarded) = EmailForward.note(in: last.body ?? "")
        if isForwarded, note.isEmpty { return last.isFromMe ? "Jij: Doorgestuurd bericht" : "Doorgestuurd bericht" }
        let text = note
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let line: String
        if !text.isEmpty {
            line = text
        } else if !last.attachments.isEmpty || last.hasAttachments {
            let count = max(1, last.attachments.count)
            line = count == 1 ? "Bijlage" : "\(count) bijlagen"
        } else {
            return nil
        }
        return last.isFromMe ? "Jij: \(line)" : line
    }

    static func notificationID(_ threadID: String) -> String { "email:\(threadID)" }

    static func threadID(fromNotification id: String) -> String? {
        id.hasPrefix("email:") ? String(id.dropFirst("email:".count)) : nil
    }

    // MARK: Connecting

    func connectICloud(address: String, password: String) async throws {
        let mailbox = try await ICloudMailbox.connect(address: address, password: password, store: store)
        add(mailbox)
        await refresh()
    }

    /// Forgets the account on this iPhone and drops its mail from the app. The mail itself stays in the mailbox.
    func disconnect(_ provider: EmailProvider) async {
        await mailboxes[provider]?.disconnect()
        store.delete(provider)
        mailboxes[provider] = nil
        accounts.removeAll { $0.provider == provider }
        threads.removeAll { $0.provider == provider }
        loaded = loaded.filter { $0.value.provider != provider }
        pendingSent = [:]
        pinnedIDs = []
        mutedIDs = []
        lockedIDs = []
        recentlyDeleted = []
        UserDefaults.standard.removeObject(forKey: Self.seenKey)
        EmailPhotoStore.forgetAll()
        if banner?.emailThreadID?.hasPrefix(provider.rawValue) == true { banner = nil }
        if accounts.isEmpty { problem = nil }
    }

    private func add(_ mailbox: any EmailMailbox) {
        mailbox.setSenderName(senderName)
        mailboxes[mailbox.account.provider] = mailbox
        accounts.removeAll { $0.provider == mailbox.account.provider }
        accounts.append(mailbox.account)
        accounts.sort { $0.provider.rawValue < $1.provider.rawValue }
    }

    // MARK: Reading

    /// Refreshes also when one is running already: that one may have started before the change it should show.
    func refreshAfterChange() async {
        while isRefreshing { try? await Task.sleep(for: .milliseconds(200)) }
        await refresh()
    }

    /// While PAVE is open: iCloud tells PAVE about new mail the moment it arrives, so an answer shows up (with its
    /// banner) within seconds instead of at the next two-minute look.
    func watchForNewMail() async {
        while !Task.isCancelled {
            guard let mailbox = mailboxes[.icloud] else {
                try? await Task.sleep(for: .seconds(30))
                continue
            }
            do {
                if try await mailbox.waitForNewMail() { await refreshAfterChange() }
            } catch {
                guard !Task.isCancelled else { return }
                // Offline, or iCloud closed the connection: try again in a bit; the regular look still runs.
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    /// The conversation on screen: no banner for it, as in Messages; it is read where you look at it.
    var openThreadID: String?

    /// `previews` off for the background refresh, which has only a few seconds.
    func refresh(previews: Bool = true) async {
        guard !mailboxes.isEmpty, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var all: [EmailThread] = []
        var failure: String?
        for (provider, mailbox) in mailboxes.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            do {
                let messages = try await mailbox.recentMessages().map(merged)
                all += EmailThreading.threads(from: messages + pendingMessages(notIn: messages))
            } catch {
                // Keep what was there, so a hiccup does not empty the list.
                all += threads.filter { $0.provider == provider }
                failure = Self.describe(error, provider: provider)
            }
        }
        contactPeople = await EmailContacts.people()
        knownPeople = EmailThreading.knownAddresses(in: all.flatMap(\.messages)).union(contactPeople.map(\.address))
        threads = all.sorted { $0.date > $1.date }
        problem = failure
        // Previews first, so the banner can show what the message says.
        if previews { await loadPreviews() }
        announceArrivals()
    }

    /// The newest message of each conversation in the list, for its preview line. Big messages (a photo) are left for
    /// when you open them.
    private func loadPreviews() async {
        let wanted = visibleThreads.prefix(40).compactMap { $0.messages.last }.filter { !$0.isLoaded && $0.size < 300_000 }
        for (provider, messages) in Dictionary(grouping: wanted, by: \.provider) {
            guard let mailbox = mailboxes[provider], let found = try? await mailbox.load(messages) else { continue }
            for message in found where message.isLoaded {
                loaded[message.id] = message
                guard let index = threads.firstIndex(where: { $0.messages.contains { $0.id == message.id } }),
                      let position = threads[index].messages.firstIndex(where: { $0.id == message.id }) else { continue }
                threads[index].messages[position] = message
            }
        }
    }

    /// Asks iOS for the contacts, so mail from people in them shows up too.
    func allowContacts() async {
        guard await EmailContacts.requestAccess() else { return }
        await refresh()
    }

    /// What you sent that the mailbox does not have yet, for a week at most. It is threaded together with the mailbox's
    /// own mail, so an answer to it (from Gmail, say) lands in the same conversation through its In-Reply-To header.
    private func pendingMessages(notIn messages: [EmailMessage]) -> [EmailMessage] {
        let onServer = Set(messages.compactMap(\.messageID).map(EmailThreading.normalizedID))
        let limit = Date.now.addingTimeInterval(-Double(EmailOutbox.keepDays) * 86_400)
        for (id, pending) in pendingSent where onServer.contains(EmailThreading.normalizedID(id)) || pending.message.date < limit {
            pendingSent[id] = nil
        }
        return pendingSent.values.map(\.message)
    }

    /// Opening a conversation: the text and attachments of every message, then marked read.
    func open(_ threadID: String) async {
        await load(threadID)
        await markRead(threadID)
    }

    /// The text and attachments of every message, without marking anything read.
    func load(_ threadID: String) async {
        guard let thread = thread(threadID), !thread.messages.allSatisfy(\.isLoaded),
              let mailbox = mailboxes[thread.provider] else { return }
        do {
            let messages = try await mailbox.load(thread.messages)
            for message in messages where message.isLoaded { loaded[message.id] = message }
            update(threadID) { $0.messages = messages.map(merged).sorted { $0.date < $1.date } }
            problem = nil
        } catch {
            problem = Self.describe(error, provider: thread.provider)
        }
    }

    func markRead(_ threadID: String) async {
        guard let thread = thread(threadID), thread.isUnread, let mailbox = mailboxes[thread.provider] else { return }
        let unread = thread.messages.filter { !$0.isRead }
        update(threadID) { thread in
            for index in thread.messages.indices { thread.messages[index].isRead = true }
        }
        if banner?.emailThreadID == threadID { banner = nil }
        do {
            try await mailbox.markRead(unread)
        } catch {
            problem = Self.describe(error, provider: thread.provider)
        }
    }

    /// Everything in one go, in one visit to the mailbox, and shown as read at once.
    func markAllRead() async {
        let unread = visibleThreads.flatMap(\.messages).filter { !$0.isRead }
        guard !unread.isEmpty else { return }
        let ids = Set(unread.map(\.id))
        for index in threads.indices {
            for position in threads[index].messages.indices where ids.contains(threads[index].messages[position].id) {
                threads[index].messages[position].isRead = true
            }
        }
        banner = nil
        for (provider, messages) in Dictionary(grouping: unread, by: \.provider) {
            do {
                try await mailboxes[provider]?.markRead(messages)
            } catch {
                problem = Self.describe(error, provider: provider)
            }
        }
    }

    func attachmentData(_ attachment: EmailAttachment, of message: EmailMessage) async throws -> Data {
        guard let mailbox = mailboxes[message.provider] else { throw EmailError.expired }
        if attachment.data == nil, message.id.hasPrefix("local:"), let (original, file) = source(of: attachment, besides: message) {
            // Something you forwarded: the same file is in the mail you got it in, so it comes from there, also when
            // the copy in Verzonden never got saved.
            if let data = try? await mailboxes[original.provider]?.attachmentData(file, of: original) { return data }
        }
        return try await mailbox.attachmentData(attachment, of: message)
    }

    /// A message in the mailbox (not one only on this iPhone) with a file of the same name and size.
    private func source(of attachment: EmailAttachment, besides message: EmailMessage) -> (EmailMessage, EmailAttachment)? {
        for thread in threads {
            for candidate in thread.messages where candidate.id != message.id && !candidate.id.hasPrefix("local:") {
                let full = loaded[candidate.id] ?? candidate
                if let file = full.attachments.first(where: { $0.name == attachment.name && $0.size == attachment.size }) {
                    return (full, file)
                }
            }
        }
        return nil
    }

    // MARK: Replying

    /// Answers `message`, or else the newest message of the conversation: to everyone on it, or with `onlySender` only
    /// to the person who wrote it. Shown at once; the next refresh brings the copy from the mailbox.
    func reply(
        in threadID: String, text: String, attachments: [EmailOutgoingAttachment],
        to message: EmailMessage? = nil, onlySender: Bool = false
    ) async throws {
        guard let thread = thread(threadID), let mailbox = mailboxes[thread.provider],
              let latest = message ?? thread.messages.last(where: { !$0.isFromMe }) ?? thread.latest else { return }
        let total = attachments.reduce(0) { $0 + $1.data.count }
        if total > EmailOutgoingAttachment.maxTotalSize, let last = attachments.last { throw EmailError.attachmentTooLarge(last.name) }
        let original = loaded[latest.id] ?? latest
        let account = mailbox.account
        let recipients = onlySender
            ? EmailReplyRecipients(onlySenderOf: original, as: account.address)
            : EmailReplyRecipients(replyingTo: original, as: account.address)
        guard !recipients.everyone.isEmpty else { throw EmailError.server("Er is niemand om aan te antwoorden.") }
        let result = try await mailbox.reply(to: original, recipients: recipients, text: text, attachments: attachments)
        let messageID = result.messageID

        let sent = EmailMessage(
            id: "local:\(UUID().uuidString)",
            provider: thread.provider,
            // Only on this iPhone until Verzonden has it; never the original's place, or deleting it would hit that one.
            location: .imap(folder: "", uid: 0),
            messageID: messageID,
            inReplyTo: original.messageID,
            references: original.references + [original.messageID].compactMap { $0 },
            from: EmailAddress(name: senderName, address: account.address),
            to: recipients.to,
            cc: recipients.cc,
            subject: EmailReplyRecipients.replySubject(original.subject),
            date: .now,
            isRead: true,
            isFromMe: true,
            hasAttachments: !attachments.isEmpty,
            body: text,
            attachments: attachments.map {
                EmailAttachment(id: $0.id.uuidString, name: $0.name, mimeType: $0.mimeType, size: $0.data.count, data: $0.data)
            }
        )
        update(threadID) { $0.messages.append(sent) }
        if let messageID { pendingSent[messageID] = (threadID, sent) }
        threads.sort { $0.date > $1.date }
    }

    /// Starts a new conversation and returns its id, so the screen can open it.
    func startConversation(
        to recipients: [EmailAddress], subject: String, text: String, attachments: [EmailOutgoingAttachment]
    ) async throws -> String? {
        guard let mailbox = mailboxes[.icloud] else { throw EmailError.expired }
        let total = attachments.reduce(0) { $0 + $1.data.count }
        if total > EmailOutgoingAttachment.maxTotalSize, let last = attachments.last { throw EmailError.attachmentTooLarge(last.name) }
        let result = try await mailbox.send(to: recipients, subject: subject, text: text, attachments: attachments)
        let messageID = result.messageID
        let account = mailbox.account
        let message = EmailMessage(
            id: "local:\(UUID().uuidString)",
            provider: account.provider,
            location: .imap(folder: "", uid: 0),
            messageID: messageID,
            from: EmailAddress(name: senderName, address: account.address),
            to: recipients,
            subject: subject,
            date: .now,
            isRead: true,
            isFromMe: true,
            hasAttachments: !attachments.isEmpty,
            body: text,
            attachments: attachments.map {
                EmailAttachment(id: $0.id.uuidString, name: $0.name, mimeType: $0.mimeType, size: $0.data.count, data: $0.data)
            }
        )
        // The same id the conversation gets once its copy is in Verzonden (EmailThreading uses the first Message-ID).
        let threadID = "\(account.provider.rawValue):\(messageID.map(EmailThreading.normalizedID) ?? message.id)"
        threads.insert(EmailThread(id: threadID, provider: account.provider, messages: [message]), at: 0)
        if let messageID { pendingSent[messageID] = (threadID, message) }
        knownPeople.formUnion(recipients.map { $0.address.lowercased() })
        return threadID
    }

    /// "Doorsturen": a new conversation with your note and the original under it.
    func forward(
        _ messages: [EmailMessage], to recipients: [EmailAddress], subject: String? = nil, note: String,
        attachments: [EmailOutgoingAttachment]
    ) async throws -> String? {
        let originals = messages.map { loaded[$0.id] ?? $0 }
        let subject = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let first = originals.min { $0.date < $1.date }?.subject ?? ""
        return try await startConversation(
            to: recipients,
            subject: subject.isEmpty ? EmailForward.subject(first) : subject,
            text: EmailForward.body(note: note, messages: originals),
            attachments: attachments
        )
    }

    /// The files of these messages, ready to send again.
    func outgoingAttachments(of messages: [EmailMessage]) async throws -> [EmailOutgoingAttachment] {
        var files: [EmailOutgoingAttachment] = []
        for message in messages {
            for attachment in (loaded[message.id] ?? message).attachments {
                let data = try await attachmentData(attachment, of: message)
                files.append(EmailOutgoingAttachment(name: attachment.name, mimeType: attachment.mimeType, data: data))
            }
        }
        return files
    }

    /// People to suggest in "Aan": who you wrote to before, and your contacts.
    var suggestedAddresses: [String] { knownPeople.sorted() }

    @ObservationIgnored private var contactPeople: [EmailAddress] = []

    /// The people for "Aan" whose name or address has `typed` in it, with their name where PAVE knows it: those whose
    /// name or address starts with it first, as Mail does.
    func suggestedPeople(matching typed: String, limit: Int = 5) -> [EmailAddress] {
        let needle = typed.trimmingCharacters(in: .whitespaces).lowercased()
        guard needle.count >= 1 else { return [] }
        var byAddress: [String: EmailAddress] = [:]
        let seen = threads.flatMap { $0.messages.flatMap { [$0.from] + $0.to + $0.cc } } + contactPeople
        for person in seen {
            let key = person.address.lowercased()
            guard knownPeople.contains(key) else { continue }
            if byAddress[key]?.name?.isEmpty != false { byAddress[key] = EmailAddress(name: person.name, address: key) }
        }
        let matches = byAddress.values.filter { person in
            person.address != needle
                && (person.address.contains(needle) || (person.name?.lowercased().contains(needle) ?? false))
        }
        func startsWith(_ person: EmailAddress) -> Bool {
            person.address.hasPrefix(needle) || (person.name?.lowercased().split(separator: " ").contains { $0.hasPrefix(needle) } ?? false)
        }
        return matches.sorted { a, b in
            if startsWith(a) != startsWith(b) { return startsWith(a) }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        .prefix(limit).map(\.self)
    }

    // MARK: Helpers

    private func merged(_ message: EmailMessage) -> EmailMessage {
        guard let known = loaded[message.id] else { return message }
        var copy = message
        copy.body = known.body
        copy.html = known.html
        copy.attachments = known.attachments
        copy.hasAttachments = known.hasAttachments || message.hasAttachments
        return copy
    }

    private func update(_ threadID: String, _ change: (inout EmailThread) -> Void) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        change(&threads[index])
    }

    static let seenKey = "emailSeenMessageIDs"

    /// The mail already announced, kept on this iPhone, so the app and the background refresh never announce the same
    /// message twice. Nil before the very first look.
    private var seenMessageIDs: Set<String>? {
        get { UserDefaults.standard.stringArray(forKey: Self.seenKey).map(Set.init) }
        set { UserDefaults.standard.set(newValue.map(Array.init), forKey: Self.seenKey) }
    }

    /// New unread mail since the last look becomes the banner, except in a muted conversation; the very first look only
    /// learns what is there.
    private func announceArrivals() {
        let incoming = visibleThreads.flatMap(\.messages).filter { !$0.isFromMe }
        let seen = seenMessageIDs
        seenMessageIDs = Set(incoming.map(\.id))
        arrivals = []
        guard let seen else { return }
        let fresh = incoming.filter { !$0.isRead && !seen.contains($0.id) }
        let threads = visibleThreads.filter { thread in
            !isMuted(thread) && thread.id != openThreadID && thread.messages.contains { message in fresh.contains { $0.id == message.id } }
        }
        arrivals = threads.map(notification(for:))
        // Also for a pinned conversation, which is not a row in the list.
        if let newest = threads.max(by: { $0.date < $1.date }) { banner = notification(for: newest) }
    }

    /// A conversation as a melding: for the list, the banner and the bin. A locked one says no more than that it is there.
    private func notification(for thread: EmailThread) -> PaveNotification {
        if isHidden(thread) {
            return PaveNotification(
                id: Self.notificationID(thread.id),
                kind: .email,
                title: "Vergrendeld gesprek",
                personName: "E-mail",
                date: thread.date,
                isUnread: thread.isUnread,
                emailThreadID: thread.id,
                emailIsLocked: true,
                emailIsMuted: isMuted(thread)
            )
        }
        return PaveNotification(
            id: Self.notificationID(thread.id),
            kind: .email,
            title: thread.subject,
            personName: thread.participantNames,
            date: thread.date,
            isUnread: thread.isUnread,
            emailThreadID: thread.id,
            emailPeople: Array(thread.participants.prefix(2)),
            emailPreview: Self.preview(of: thread),
            emailIsLocked: isLocked(thread),
            emailIsMuted: isMuted(thread)
        )
    }

    /// Asked from outside Meldingen (the banner): Meldingen opens this conversation as soon as it is on screen.
    var threadToOpen: String?

    /// Asked of Ayla from a chat: once this conversation is open, she summarises it or proposes a reply (with what
    /// the user wants it to say). The thread asks for her consent first, as when you tap the button yourself.
    var aylaRequest: (threadID: String, task: EmailAylaTask, wish: String)?

    /// A conversation by the words you use for it: a name, an address or the subject. Nil when none or several fit.
    func thread(matching words: String?) -> EmailThread? {
        let named = threads.map { AylaAppCommand.Named(id: $0.id, name: "\($0.participantNames) \($0.participants.map(\.address).joined(separator: " ")) \($0.subject)") }
        if let found = AylaAppAction.best(words, in: named) { return thread(found.id) }
        // "de laatste mail", or no words at all: the newest conversation.
        if words.map({ $0.isEmpty || $0.lowercased().contains("laatste") || $0.lowercased().contains("nieuwste") }) ?? true { return threads.max { $0.date < $1.date } }
        return nil
    }

    /// Conversations whose names, subject or text contain `text`, for the search in Meldingen.
    func threadIDs(matching text: String) -> Set<String> {
        let needle = text.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }
        return Set(visibleThreads.filter { thread in
            guard !isHidden(thread) else { return false }
            let fields = [thread.subject, thread.participantNames]
                + thread.participants.map(\.address)
                + thread.messages.compactMap(\.body)
                + thread.messages.flatMap { $0.attachments.map(\.name) }
            return fields.contains { $0.localizedCaseInsensitiveContains(needle) }
        }.map(\.id))
    }

    func dismissBanner() { banner = nil }

    private static func describe(_ error: Error, provider: EmailProvider) -> String {
        let text = (error as? LocalizedError)?.errorDescription ?? EmailError.network.errorDescription ?? ""
        return "\(provider.title): \(text)"
    }
}
