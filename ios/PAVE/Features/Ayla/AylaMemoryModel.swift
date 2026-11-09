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

    /// One line on the card under Ayla's answer: a fact to keep, or an old note to take away.
    struct Change: Hashable, Identifiable {
        enum Kind: Hashable {
            case keep
            /// Take this note away; it is out of date because of what you told.
            case remove(AylaMemory)
        }

        let suggestion: AylaReply.MemorySuggestion
        let kind: Kind

        var id: String {
            switch kind {
            case .keep: "keep-\(suggestion.text)"
            case .remove(let note): "remove-\(note.id)"
            }
        }
    }

    /// The card under Ayla's answer. Once you decided, the card makes room; kept notes stay recognisable, also when
    /// you open the conversation again later. Facts Ayla already knows in other words are left out.
    func decision(for reply: AylaReply) -> Decision? {
        if let decision = decisions[reply.id] { return decision }
        let suggestions = reply.suggestedMemories
        guard !suggestions.isEmpty else { return nil }
        guard changes(in: reply).isEmpty else { return nil }
        let isDone = suggestions.allSatisfy { $0.text.isEmpty || memories.contains($0.text) }
        return isDone ? .saved : .known
    }

    /// The lines of a card being saved, so they stay put while the notes change underneath.
    private var savingChanges: [String: [Change]] = [:]

    /// What is still to decide in a reply: new facts Ayla does not know yet, and old notes that are still there.
    func changes(in reply: AylaReply) -> [Change] {
        if let saving = savingChanges[reply.id] { return saving }
        return reply.suggestedMemories.flatMap { suggestion -> [Change] in
            var changes: [Change] = []
            if !suggestion.text.isEmpty, !memories.knows(suggestion.text) {
                changes.append(Change(suggestion: suggestion, kind: .keep))
            }
            if let replaces = suggestion.replaces, let note = memories.note(withText: replaces) {
                changes.append(Change(suggestion: suggestion, kind: .remove(note)))
            }
            return changes
        }
    }

    /// Does what you kept ticked: saves new facts first, then takes old notes away. When something fails, the card
    /// stays so you can try again.
    func accept(_ changes: [Change], replyID: String, conversationID: String?) {
        guard let service, !changes.isEmpty, decisions[replyID] != .saving else { return }
        decisions[replyID] = .saving
        savingChanges[replyID] = changes
        Task {
            var failed = false
            for change in changes where change.kind == .keep && !memories.knows(change.suggestion.text) {
                do {
                    let memory = try await service.remember(
                        change.suggestion.text, category: change.suggestion.category, source: .ayla, conversationID: conversationID
                    )
                    memories.notes.insert(memory, at: 0)
                    if state != .ready { state = .ready }
                } catch AylaError.notSetUp {
                    failed = true
                    state = .notSetUp
                } catch {
                    failed = true
                }
            }
            for change in changes {
                guard case .remove(let note) = change.kind, memories.notes.contains(where: { $0.id == note.id }) else { continue }
                do {
                    try await service.forgetMemory(id: note.id)
                    memories.notes.removeAll { $0.id == note.id }
                } catch {
                    failed = true
                }
            }
            savingChanges[replyID] = nil
            decisions[replyID] = failed ? .failed : .saved
            let removes = changes.contains { if case .remove = $0.kind { true } else { false } }
            if !failed { AccessibilityNotification.Announcement(removes ? "Bijgewerkt" : "Onthouden").post() }
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
