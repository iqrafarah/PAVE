import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct AylaMemoryModelTests {
    private final class FakeMemory: AylaService, @unchecked Sendable {
        var stored = AylaMemories()
        var fails = false
        var notSetUp = false
        var saved: [(String, AylaMemory.Source, String?)] = []
        var forgotten: [String] = []

        func send(_ request: AylaRequest) async throws -> AylaReply { throw AylaError.unavailable }
        func conversations(limit: Int) async throws -> AylaConversationList { AylaConversationList() }
        func messages(in conversationID: String) async throws -> [AylaStoredMessage] { [] }
        func setPinned(_ isPinned: Bool, conversationID: String) async throws {}
        func firstName() async -> String? { nil }

        func memories() async throws -> AylaMemories {
            if notSetUp { throw AylaError.notSetUp }
            return stored
        }
        func remember(_ text: String, source: AylaMemory.Source, conversationID: String?) async throws -> AylaMemory {
            saved.append((text, source, conversationID))
            if notSetUp { throw AylaError.notSetUp }
            if fails { throw AylaError.noConnection }
            return AylaMemory(id: "m\(saved.count)", text: text, source: source, createdAt: .now)
        }
        func forgetMemory(id: String) async throws {
            forgotten.append(id)
            if fails { throw AylaError.noConnection }
        }
        func forgetAllMemories() async throws {
            if fails { throw AylaError.noConnection }
        }
        func setMemoryEnabled(_ isEnabled: Bool) async throws {
            if fails { throw AylaError.noConnection }
        }
    }

    private func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    private let suggestion = AylaReply(id: "r1", conversationId: "c1", text: "Mooi!", memory: .init(text: "Je hebt stage gelopen bij LiveWall."))

    @Test func aSuggestionIsSavedOnlyWhenKept() async {
        let fake = FakeMemory()
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        #expect(memory.decision(for: suggestion) == nil)
        #expect(fake.saved.isEmpty)

        memory.accept(suggestion.memory!, replyID: "r1", conversationID: "c1")
        await waitFor { memory.decision(for: suggestion) == .saved }

        #expect(memory.decision(for: suggestion) == .saved)
        #expect(fake.saved.first?.0 == "Je hebt stage gelopen bij LiveWall.")
        #expect(fake.saved.first?.1 == .ayla)
        #expect(fake.saved.first?.2 == "c1")
        #expect(memory.notes.map(\.text) == ["Je hebt stage gelopen bij LiveWall."])
    }

    @Test func decliningSavesNothing() async {
        let fake = FakeMemory()
        let memory = AylaMemoryModel(service: fake)
        memory.decline(replyID: "r1")
        #expect(memory.decision(for: suggestion) == .declined)
        #expect(fake.saved.isEmpty)
    }

    @Test func aKeptNoteIsRecognisedInAnOldConversation() async {
        let fake = FakeMemory()
        fake.stored = AylaMemories(notes: [AylaMemory(id: "m1", text: "je hebt stage gelopen bij LiveWall", source: .ayla, createdAt: .now)])
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        #expect(memory.decision(for: suggestion) == .saved)
    }

    @Test func aFailedSaveCanBeTriedAgain() async {
        let fake = FakeMemory()
        fake.fails = true
        let memory = AylaMemoryModel(service: fake)
        memory.accept(suggestion.memory!, replyID: "r1", conversationID: "c1")
        await waitFor { memory.decision(for: suggestion) == .failed }
        #expect(memory.decision(for: suggestion) == .failed)
        #expect(memory.notes.isEmpty)
    }

    @Test func forgettingComesBackWhenItFails() async {
        let fake = FakeMemory()
        let note = AylaMemory(id: "m1", text: "Je studeert ICT.", source: .user, createdAt: .now)
        fake.stored = AylaMemories(notes: [note])
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        fake.fails = true

        memory.forget(note)
        #expect(memory.notes.isEmpty)
        await waitFor { memory.problem != nil }

        #expect(memory.notes == [note])
        #expect(memory.problem == AylaMessages.memoryForgetFailed)
    }

    @Test func withoutTheTablesTheScreenSaysSo() async {
        let fake = FakeMemory()
        fake.notSetUp = true
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        #expect(memory.state == .notSetUp)
    }

    @Test func theDemoAccountHasNoMemory() {
        #expect(AylaMemoryModel(service: nil).state == .unavailable)
    }

    @Test func turningItOffGoesBackWhenRefused() async {
        let fake = FakeMemory()
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        fake.fails = true
        memory.setEnabled(false)
        #expect(!memory.memories.isEnabled)
        await waitFor { memory.memories.isEnabled }
        #expect(memory.memories.isEnabled)
    }
}
