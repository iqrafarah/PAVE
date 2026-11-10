import Foundation
import Observation
import PAVECore

@Observable
final class AylaChatModel {
    enum Phase: Equatable {
        case idle
        case thinking
        case failed(String)
    }

    struct Entry: Identifiable, Equatable {
        enum Role {
            case user
            case ayla
        }

        let id: String
        let role: Role
        let text: String
        var reply: AylaReply?
        var attachments: [String] = []
    }

    private(set) var entries: [Entry] = []
    private(set) var phase = Phase.idle
    private(set) var conversationID: String?
    private(set) var firstName: String?
    /// The welcome waits for the name, so it does not jump when the name comes in.
    private(set) var isGreetingReady: Bool
    private(set) var conversationList = AylaConversationList()
    /// The list is being loaded, the first time or because someone pulled it down.
    private(set) var isLoadingList = false
    /// Loading the list failed and nothing is shown yet.
    private(set) var listFailed = false
    /// The list was asked for at least once; before that an empty list says nothing yet.
    private(set) var hasLoadedList = false
    /// Renaming, deleting or pinning a conversation did not work; the chats screen shows it.
    var chatsProblem: String?
    /// How many conversations are loaded; scrolling to the end loads more.
    private(set) var conversationLimit = 50
    /// Conversations that were just deleted and can still be brought back (`undoDeletion`).
    private(set) var pendingDeletion: [AylaConversation] = []
    @ObservationIgnored private var deletionTask: Task<Void, Never>?
    @ObservationIgnored private var refreshAgain = false
    private let undoWindow: Duration
    private(set) var isLoadingConversation = false
    var draft = ""
    /// Files added with the plus button, sent with the next message.
    private(set) var attachments: [AylaAttachment] = []

    let service: (any AylaService)?
    private let nameWait: Duration
    private var lastQuestion: String?

    /// `nameWait`: how long the welcome waits for the name; after that it shows without it.
    /// `undoWindow`: how long a deleted conversation can be brought back before it is really deleted.
    init(service: (any AylaService)?, nameWait: Duration = .seconds(1.5), undoWindow: Duration = .seconds(5)) {
        self.service = service
        self.nameWait = nameWait
        self.undoWindow = undoWindow
        isGreetingReady = service == nil
    }

    var isAvailable: Bool { service != nil }

    /// Choices from Ayla's last reply, shown instead of the text field.
    var pendingQuestion: AylaReply.Question? {
        guard phase != .thinking, let last = entries.last, last.role == .ayla else { return nil }
        return last.reply?.question
    }

    var lastAylaEntryID: String? {
        entries.last { $0.role == .ayla }?.id
    }

    func start() async {
        guard let service else { return }
        let wait = nameWait
        let timeout = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self?.isGreetingReady = true
        }
        let name = await service.firstName()
        timeout.cancel()
        // A name that comes in after the welcome is shown is left out, so the welcome does not jump.
        if !isGreetingReady {
            firstName = name
            isGreetingReady = true
        }
        await refreshConversations()
    }

    func send(_ text: String) {
        guard let turn = prepare(text, input: .text) else { return }
        Task { await complete(turn) }
    }

    /// Sends a question and waits for Ayla's answer, for the voice conversation. Nil when it failed;
    /// the chat then shows what went wrong, just like after a typed question.
    func ask(_ text: String, input: AylaInput) async -> AylaReply? {
        guard let turn = prepare(text, input: input) else { return nil }
        return await complete(turn)
    }

    private struct Turn {
        let service: any AylaService
        let request: AylaRequest
        let text: String
        let files: [AylaAttachment]
    }

    /// Shows the question at once and returns what to send, or nil when nothing can be sent now.
    private func prepare(_ text: String, input: AylaInput) -> Turn? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let service, !text.isEmpty, phase != .thinking else { return nil }
        let files = attachments
        draft = ""
        attachments = []
        if case .failed = phase, lastQuestion == text, entries.last?.role == .user, entries.last?.attachments == files.map(\.name) {
            // Retrying the same question: keep the message that is already shown.
        } else {
            entries.append(Entry(id: UUID().uuidString, role: .user, text: text, attachments: files.map(\.name)))
        }
        lastQuestion = text
        phase = .thinking
        let request = AylaRequest(conversationId: conversationID, text: text, device: .phone, input: input, attachments: files)
        return Turn(service: service, request: request, text: text, files: files)
    }

    @discardableResult
    private func complete(_ turn: Turn) async -> AylaReply? {
        do {
            let reply = try await turn.service.send(turn.request)
            conversationID = reply.conversationId
            entries.append(Entry(id: reply.id, role: .ayla, text: reply.text, reply: reply))
            phase = .idle
            await refreshConversations()
            return reply
        } catch {
            phase = .failed(Self.message(for: AylaError(error)))
            if draft.isEmpty { draft = turn.text }
            if attachments.isEmpty { attachments = turn.files }
            return nil
        }
    }

    /// Adds a file to the next message. Returns false when there is no room for another one.
    @discardableResult
    func attach(_ file: AylaAttachment) -> Bool {
        guard attachments.count < AylaAttachment.maxCount else { return false }
        attachments.removeAll { $0.name == file.name }
        attachments.append(file)
        return true
    }

    func removeAttachment(_ file: AylaAttachment) {
        attachments.removeAll { $0.name == file.name }
    }

    func newConversation() {
        guard phase != .thinking else { return }
        entries = []
        conversationID = nil
        lastQuestion = nil
        phase = .idle
        draft = ""
        attachments = []
    }

    func open(_ conversation: AylaConversation) async {
        guard let service, phase != .thinking else { return }
        isLoadingConversation = true
        defer { isLoadingConversation = false }
        do {
            let messages = try await service.messages(in: conversation.id)
            entries = messages.map { message in
                Entry(id: message.id, role: message.role == .user ? .user : .ayla, text: message.text, reply: message.reply)
            }
            conversationID = conversation.id
            lastQuestion = nil
            phase = .idle
        } catch {
            phase = .failed(Self.message(for: AylaError(error)))
        }
    }

    func refreshConversations() async {
        guard let service else { return }
        // A change that comes in while loading is fetched right after, so it is never missed.
        guard !isLoadingList else {
            refreshAgain = true
            return
        }
        isLoadingList = true
        defer { isLoadingList = false }
        repeat {
            refreshAgain = false
            do {
                var list = try await service.conversations(limit: conversationLimit)
                // Deleted ones that can still be brought back are not on the server's side yet.
                let pending = Set(pendingDeletion.map(\.id))
                list.conversations.removeAll { pending.contains($0.id) }
                // A refresh that shows nothing new (often the echo of your own change) leaves the list alone, so the
                // rows are not drawn again.
                if !list.looksTheSame(as: conversationList) { conversationList = list }
                listFailed = false
            } catch {
                listFailed = conversationList.conversations.isEmpty
            }
        } while refreshAgain
        hasLoadedList = true
    }

    /// Keeps the list up to date while the app is open: a chat started or changed on the web or the Watch shows up
    /// by itself.
    func followConversationChanges() async {
        guard let service else { return }
        for await _ in service.conversationChanges() {
            await refreshConversations()
        }
    }

    /// There may be older conversations than the ones loaded.
    var canLoadMore: Bool {
        conversationList.conversations.count >= conversationLimit
    }

    func loadMoreConversations() async {
        guard canLoadMore, !isLoadingList else { return }
        conversationLimit += 50
        await refreshConversations()
    }

    /// Pins or unpins a conversation. The list changes at once and goes back if Supabase refuses.
    func togglePin(_ conversation: AylaConversation) {
        guard let service, conversationList.canPin else { return }
        let isPinned = !conversation.isPinned
        let before = conversationList
        conversationList.setPinned(isPinned, id: conversation.id)
        Task {
            do {
                try await service.setPinned(isPinned, conversationID: conversation.id)
            } catch {
                conversationList = before
                chatsProblem = AylaMessages.pinFailed
            }
        }
    }

    /// Gives a conversation another name. The list changes at once and goes back if Supabase refuses.
    func rename(_ conversation: AylaConversation, to text: String) {
        guard let service, let title = AylaConversation.cleanTitle(text), title != conversation.title else { return }
        let before = conversationList
        conversationList.rename(id: conversation.id, to: title)
        Task {
            do {
                try await service.rename(title, conversationID: conversation.id)
            } catch {
                conversationList = before
                chatsProblem = AylaMessages.renameFailed
            }
        }
    }

    /// Removes conversations from the list at once; they are really deleted after `undoWindow`, unless
    /// `undoDeletion` brings them back first. When the open conversation is one of them, the chat starts afresh.
    func delete(_ conversations: [AylaConversation]) {
        guard service != nil, !conversations.isEmpty else { return }
        commitPendingDeletion()
        let ids = Set(conversations.map(\.id))
        conversationList.conversations.removeAll { ids.contains($0.id) }
        if let conversationID, ids.contains(conversationID) { newConversation() }
        pendingDeletion = conversations
        let wait = undoWindow
        deletionTask = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self?.commitPendingDeletion()
        }
    }

    func delete(_ conversation: AylaConversation) {
        delete([conversation])
    }

    /// Brings the conversations that were just deleted back.
    func undoDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
        let present = Set(conversationList.conversations.map(\.id))
        conversationList.conversations += pendingDeletion.filter { !present.contains($0.id) }
        pendingDeletion = []
    }

    /// Deletes the pending conversations now, for instance when another one is deleted or the app goes away.
    func commitPendingDeletion() {
        guard let service, !pendingDeletion.isEmpty else { return }
        deletionTask?.cancel()
        deletionTask = nil
        let conversations = pendingDeletion
        pendingDeletion = []
        Task {
            var failed: [AylaConversation] = []
            for conversation in conversations {
                do {
                    try await service.delete(conversationID: conversation.id)
                } catch {
                    failed.append(conversation)
                }
            }
            guard !failed.isEmpty else { return }
            let present = Set(conversationList.conversations.map(\.id))
            conversationList.conversations += failed.filter { !present.contains($0.id) }
            chatsProblem = AylaMessages.deleteFailed
        }
    }

    /// Pins several conversations at once, or unpins them when they all were pinned already.
    func togglePin(_ conversations: [AylaConversation]) {
        let pin = !conversations.allSatisfy(\.isPinned)
        for conversation in conversations where conversation.isPinned != pin {
            togglePin(conversation)
        }
    }

    /// Messages that contain `text`, with the conversation each is in. Only conversations in the list are shown.
    func searchMessages(_ text: String) async -> [(hit: AylaSearchHit, conversation: AylaConversation)] {
        guard let service, let hits = try? await service.searchMessages(text) else { return [] }
        var seen = Set<String>()
        return hits.compactMap { hit in
            guard !seen.contains(hit.conversationID),
                  let conversation = conversationList.conversations.first(where: { $0.id == hit.conversationID })
            else { return nil }
            seen.insert(hit.conversationID)
            return (hit, conversation)
        }
    }

    /// The last messages of a conversation, for the preview when you press and hold it.
    func preview(of conversation: AylaConversation) async -> [AylaStoredMessage] {
        guard let service, let messages = try? await service.messages(in: conversation.id) else { return [] }
        return Array(messages.suffix(4))
    }

    static func message(for error: AylaError) -> String {
        switch error {
        case .noConnection: AylaMessages.noConnection
        case .notSignedIn, .insufficientAssurance: AylaMessages.signInAgain
        case .conversationNotFound: AylaMessages.conversationGone
        case .unavailable: AylaMessages.unavailable
        }
    }
}
