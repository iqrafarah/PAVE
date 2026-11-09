import Foundation
import Observation
import PAVECore

/// What Ayla remembers about you, for "Wat Ayla over je weet" and the "Zal ik dit onthouden?" card in the chat.
/// Nothing is saved by itself: a suggestion from Ayla is saved only when you tap "Onthouden".
@Observable
final class AylaMemoryModel {
    enum State: Equatable {
        case loading
        case ready
        /// The tables are not in the database yet.
        case notSetUp
        /// Signed in with the demo account: there is no Ayla.
        case unavailable
        case failed(String)
    }

    /// What you did with a suggestion in the chat.
    enum Decision: Equatable {
        case saving
        case saved
        case declined
        case failed
        /// Ayla already knows this in other words, so there is nothing to ask.
        case known
    }

    private(set) var state = State.loading
    private(set) var memories = AylaMemories()
    private(set) var decisions: [String: Decision] = [:]
    /// Saving, changing or deleting did not work; the screen shows it.
    var problem: String?

    private let service: (any AylaService)?

    init(service: (any AylaService)?) {
        self.service = service
        if service == nil { state = .unavailable }
    }

    var notes: [AylaMemory] { memories.notes }

    func load() async {
        guard let service else { return }
        do {
            memories = try await service.memories()
            state = .ready
        } catch AylaError.notSetUp {
            state = .notSetUp
        } catch {
            if state != .ready { state = .failed(AylaChatModel.message(for: AylaError(error))) }
        }
    }

    /// The card under Ayla's answer. Once you decided, the card makes room; a kept note stays recognisable, also
    /// when you open the conversation again later.
    func decision(for reply: AylaReply) -> Decision? {
        if let decision = decisions[reply.id] { return decision }
        guard let text = reply.memory?.text else { return nil }
        if memories.contains(text) { return .saved }
        if memories.knows(text) { return .known }
        return nil
    }

    func accept(_ suggestion: AylaReply.MemorySuggestion, replyID: String, conversationID: String?) {
        guard let service, decisions[replyID] != .saving else { return }
        decisions[replyID] = .saving
        Task {
            do {
                let memory = try await service.remember(suggestion.text, source: .ayla, conversationID: conversationID)
                memories.notes.insert(memory, at: 0)
                decisions[replyID] = .saved
                if state != .ready { state = .ready }
            } catch AylaError.notSetUp {
                decisions[replyID] = .failed
                state = .notSetUp
            } catch {
                decisions[replyID] = .failed
            }
        }
    }

    func decline(replyID: String) {
        decisions[replyID] = .declined
    }

    func add(_ text: String) {
        guard let service, let text = AylaMemory.clean(text) else { return }
        Task {
            do {
                let memory = try await service.remember(text, source: .user, conversationID: nil)
                memories.notes.insert(memory, at: 0)
            } catch {
                problem = AylaMessages.memorySaveFailed
            }
        }
    }

    func update(_ memory: AylaMemory, to text: String) {
        guard let service, let text = AylaMemory.clean(text), text != memory.text,
              let index = memories.notes.firstIndex(where: { $0.id == memory.id })
        else { return }
        memories.notes[index].text = text
        Task {
            do {
                try await service.updateMemory(text, id: memory.id)
            } catch {
                if let index = memories.notes.firstIndex(where: { $0.id == memory.id }) { memories.notes[index].text = memory.text }
                problem = AylaMessages.memorySaveFailed
            }
        }
    }

    func forget(_ memory: AylaMemory) {
        guard let service, let index = memories.notes.firstIndex(where: { $0.id == memory.id }) else { return }
        memories.notes.remove(at: index)
        Task {
            do {
                try await service.forgetMemory(id: memory.id)
            } catch {
                memories.notes.insert(memory, at: min(index, memories.notes.count))
                problem = AylaMessages.memoryForgetFailed
            }
        }
    }

    func forgetAll() {
        guard let service, !memories.notes.isEmpty else { return }
        let before = memories.notes
        memories.notes = []
        Task {
            do {
                try await service.forgetAllMemories()
            } catch {
                memories.notes = before
                problem = AylaMessages.memoryForgetFailed
            }
        }
    }

    func setEnabled(_ isEnabled: Bool) {
        guard let service, isEnabled != memories.isEnabled else { return }
        memories.isEnabled = isEnabled
        Task {
            do {
                try await service.setMemoryEnabled(isEnabled)
            } catch {
                memories.isEnabled = !isEnabled
                problem = AylaMessages.memorySaveFailed
            }
        }
    }
}
