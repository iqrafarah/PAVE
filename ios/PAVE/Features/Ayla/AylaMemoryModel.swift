import Foundation
import Observation
import PAVECore
import SwiftUI

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

    /// A note that was just forgotten and can still be brought back (`undoForget`).
    private(set) var pendingForget: AylaMemory?
    @ObservationIgnored private var forgetTask: Task<Void, Never>?
    @ObservationIgnored private var pendingIndex = 0

    private let service: (any AylaService)?
    private let undoWindow: Duration

    init(service: (any AylaService)?, undoWindow: Duration = .seconds(5)) {
        self.service = service
        self.undoWindow = undoWindow
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

    /// The card under Ayla's answer. Once you decided, the card makes room; kept notes stay recognisable, also when
    /// you open the conversation again later. Facts Ayla already knows in other words are left out.
    func decision(for reply: AylaReply) -> Decision? {
        if let decision = decisions[reply.id] { return decision }
        let suggestions = reply.suggestedMemories
        guard !suggestions.isEmpty else { return nil }
        if suggestions.allSatisfy({ memories.contains($0.text) }) { return .saved }
        if pending(in: reply).isEmpty { return .known }
        return nil
    }

    /// The suggestions in a reply that Ayla does not know yet.
    func pending(in reply: AylaReply) -> [AylaReply.MemorySuggestion] {
        reply.suggestedMemories.filter { !memories.knows($0.text) }
    }

    /// Saves the facts you kept ticked. When one fails, the card stays so you can try again.
    func accept(_ suggestions: [AylaReply.MemorySuggestion], replyID: String, conversationID: String?) {
        guard let service, !suggestions.isEmpty, decisions[replyID] != .saving else { return }
        decisions[replyID] = .saving
        Task {
            var failed = false
            for suggestion in suggestions where !memories.knows(suggestion.text) {
                do {
                    let memory = try await service.remember(
                        suggestion.text, category: suggestion.category, source: .ayla, conversationID: conversationID
                    )
                    memories.notes.insert(memory, at: 0)
                    if state != .ready { state = .ready }
                } catch AylaError.notSetUp {
                    failed = true
                    state = .notSetUp
                    break
                } catch {
                    failed = true
                }
            }
            decisions[replyID] = failed ? .failed : .saved
            if !failed { AccessibilityNotification.Announcement("Onthouden").post() }
        }
    }

    func decline(replyID: String) {
        decisions[replyID] = .declined
    }

    func add(_ text: String, category: AylaMemory.Category) {
        guard let service, let text = AylaMemory.clean(text) else { return }
        Task {
            do {
                let memory = try await service.remember(text, category: category, source: .user, conversationID: nil)
                memories.notes.insert(memory, at: 0)
            } catch {
                problem = AylaMessages.memorySaveFailed
            }
        }
    }

    func update(_ memory: AylaMemory, to text: String, category: AylaMemory.Category) {
        guard let service, let text = AylaMemory.clean(text), text != memory.text || category != memory.category,
              let index = memories.notes.firstIndex(where: { $0.id == memory.id })
        else { return }
        memories.notes[index].text = text
        memories.notes[index].category = category
        Task {
            do {
                try await service.updateMemory(text, category: category, id: memory.id)
            } catch {
                if let index = memories.notes.firstIndex(where: { $0.id == memory.id }) { memories.notes[index] = memory }
                problem = AylaMessages.memorySaveFailed
            }
        }
    }

    /// Takes the note away at once; it is really forgotten after `undoWindow`, unless `undoForget` brings it back
    /// first, as with deleting a chat.
    func forget(_ memory: AylaMemory) {
        guard service != nil, let index = memories.notes.firstIndex(where: { $0.id == memory.id }) else { return }
        commitPendingForget()
        memories.notes.remove(at: index)
        pendingForget = memory
        pendingIndex = index
        let wait = undoWindow
        forgetTask = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self?.commitPendingForget()
        }
    }

    func undoForget() {
        forgetTask?.cancel()
        forgetTask = nil
        guard let memory = pendingForget else { return }
        pendingForget = nil
        memories.notes.insert(memory, at: min(pendingIndex, memories.notes.count))
    }

    /// Forgets the pending note now, for instance when another one is forgotten or the screen closes.
    func commitPendingForget() {
        forgetTask?.cancel()
        forgetTask = nil
        guard let service, let memory = pendingForget else { return }
        pendingForget = nil
        let index = pendingIndex
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
