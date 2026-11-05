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
    }

    private(set) var entries: [Entry] = []
    private(set) var phase = Phase.idle
    private(set) var conversationID: String?
    private(set) var firstName: String?
    private(set) var conversations: [AylaConversation] = []
    private(set) var isLoadingConversation = false
    var draft = ""

    let service: (any AylaService)?
    private var lastQuestion: String?

    init(service: (any AylaService)?) {
        self.service = service
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
        firstName = await service.firstName()
        await refreshConversations()
    }

    func send(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let service, !text.isEmpty, phase != .thinking else { return }
        draft = ""
        if case .failed = phase, lastQuestion == text, entries.last?.role == .user {
            // Retrying the same question: keep the message that is already shown.
        } else {
            entries.append(Entry(id: UUID().uuidString, role: .user, text: text))
        }
        lastQuestion = text
        phase = .thinking

        let request = AylaRequest(conversationId: conversationID, text: text, device: .phone, input: .text)
        Task {
            do {
                let reply = try await service.send(request)
                conversationID = reply.conversationId
                entries.append(Entry(id: reply.id, role: .ayla, text: reply.text, reply: reply))
                phase = .idle
                await refreshConversations()
            } catch {
                phase = .failed(Self.message(for: AylaError(error)))
                if draft.isEmpty { draft = text }
            }
        }
    }

    func newConversation() {
        guard phase != .thinking else { return }
        entries = []
        conversationID = nil
        lastQuestion = nil
        phase = .idle
        draft = ""
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
        if let list = try? await service.conversations() {
            conversations = list
        }
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
