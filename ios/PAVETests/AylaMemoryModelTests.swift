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
        var saved: [(String, AylaMemory.Category, AylaMemory.Source, String?)] = []
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
        func remember(_ text: String, categories: [AylaMemory.Category], source: AylaMemory.Source, conversationID: String?) async throws -> AylaMemory {
            saved.append((text, categories.first ?? .personal, source, conversationID))
            if notSetUp { throw AylaError.notSetUp }
            if fails { throw AylaError.noConnection }
            return AylaMemory(id: "m\(saved.count)", text: text, categories: categories, source: source, createdAt: .now)
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

    private let suggestion = AylaReply(id: "r1", conversationId: "c1", text: "Mooi!", memories: [.init(text: "Je hebt stage gelopen bij LiveWall.", category: .work)])
    private let two = AylaReply(id: "r2", conversationId: "c1", text: "Sterk!", memories: [
        .init(text: "Je studeert ICT aan Fontys.", category: .education),
        .init(text: "Je werkt als leidinggevende bij de Plus.", category: .work),
    ])

    @Test func aSuggestionIsSavedOnlyWhenKept() async {
        let fake = FakeMemory()
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        #expect(memory.decision(for: suggestion) == nil)
        #expect(fake.saved.isEmpty)

        memory.accept(memory.changes(in: suggestion), replyID: "r1", conversationID: "c1")
        await waitFor { memory.decision(for: suggestion) == .saved }

        #expect(memory.decision(for: suggestion) == .saved)
        #expect(fake.saved.first?.0 == "Je hebt stage gelopen bij LiveWall.")
        #expect(fake.saved.first?.1 == .work)
        #expect(fake.saved.first?.2 == .ayla)
        #expect(fake.saved.first?.3 == "c1")
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

    @Test func aFactAylaKnowsInOtherWordsIsNotAskedAgain() async {
        let fake = FakeMemory()
        fake.stored = AylaMemories(notes: [AylaMemory(id: "m1", text: "Je studeert ICT aan Fontys en werkt als leidinggevende bij de Plus.", source: .ayla, createdAt: .now)])
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        let again = AylaReply(id: "r9", conversationId: "c2", text: "Top!", memories: [.init(text: "Je werkt als leidinggevende bij de Plus.", category: .work)])
        #expect(memory.decision(for: again) == .known)
    }

    @Test func everyFactIsSavedOnItsOwnWithItsCategory() async {
        let fake = FakeMemory()
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        #expect(memory.changes(in: two).count == 2)

        memory.accept(memory.changes(in: two), replyID: "r2", conversationID: "c1")
        await waitFor { memory.decision(for: two) == .saved }

        #expect(fake.saved.map(\.0) == ["Je studeert ICT aan Fontys.", "Je werkt als leidinggevende bij de Plus."])
        #expect(fake.saved.map(\.1) == [.education, .work])
        #expect(memory.memories.byCategory.map(\.category) == [.education, .work])
    }

    @Test func onlyTheTickedFactsAreSaved() async {
        let fake = FakeMemory()
        let memory = AylaMemoryModel(service: fake)
        memory.accept([memory.changes(in: two)[1]], replyID: "r2", conversationID: "c1")
        await waitFor { memory.decision(for: two) == .saved }
        #expect(fake.saved.map(\.0) == ["Je werkt als leidinggevende bij de Plus."])
    }

    @Test func aFactAlreadyKeptIsLeftOutOfTheCard() async {
        let fake = FakeMemory()
        fake.stored = AylaMemories(notes: [AylaMemory(id: "m1", text: "Je studeert ICT op Fontys.", category: .education, source: .ayla, createdAt: .now)])
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        #expect(memory.changes(in: two).map(\.text) == ["Je werkt als leidinggevende bij de Plus."])
        #expect(memory.decision(for: two) == nil)
    }

    @Test func aNewJobCanReplaceTheOldOneOrLeaveItBe() async {
        let fake = FakeMemory()
        let old = AylaMemory(id: "plus", text: "Je werkt als leidinggevende bij de Plus.", category: .work, source: .ayla, createdAt: .now)
        fake.stored = AylaMemories(notes: [old])
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        let reply = AylaReply(id: "r5", conversationId: "c1", text: "Gefeliciteerd!", memories: [
            .init(text: "Je werkt bij Albert Heijn.", category: .work, replaces: "je werkt als leidinggevende bij de plus"),
        ])
        let changes = memory.changes(in: reply)
        #expect(changes.map(\.isRemoval) == [false, true])

        memory.accept(changes, replyID: "r5", conversationID: "c1")
        await waitFor { memory.decision(for: reply) == .saved }

        #expect(fake.forgotten == ["plus"])
        #expect(memory.notes.map(\.text) == ["Je werkt bij Albert Heijn."])
    }

    @Test func keepingTheOldJobLeavesItStanding() async {
        let fake = FakeMemory()
        let old = AylaMemory(id: "plus", text: "Je werkt als leidinggevende bij de Plus.", category: .work, source: .ayla, createdAt: .now)
        fake.stored = AylaMemories(notes: [old])
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        let reply = AylaReply(id: "r6", conversationId: "c1", text: "Leuk!", memories: [
            .init(text: "Je werkt bij Albert Heijn.", category: .work, replaces: old.text),
        ])

        memory.accept(memory.changes(in: reply).filter { !$0.isRemoval }, replyID: "r6", conversationID: "c1")
        await waitFor { memory.decision(for: reply) == .saved }

        #expect(fake.forgotten.isEmpty)
        #expect(Set(memory.notes.map(\.text)) == ["Je werkt bij Albert Heijn.", old.text])
    }

    @Test func sayingAJobIsOverOnlyOffersToTakeItAway() async {
        let fake = FakeMemory()
        let old = AylaMemory(id: "plus", text: "Je werkt als leidinggevende bij de Plus.", category: .work, source: .ayla, createdAt: .now)
        fake.stored = AylaMemories(notes: [old])
        let memory = AylaMemoryModel(service: fake)
        await memory.load()
        let reply = AylaReply(id: "r7", conversationId: "c1", text: "Oké.", memories: [.init(text: "", category: .work, replaces: old.text)])
        #expect(memory.changes(in: reply).map(\.isRemoval) == [true])
        memory.decline(replyID: "r7")
        #expect(memory.notes == [old])
    }

    @Test func aFailedSaveCanBeTriedAgain() async {
        let fake = FakeMemory()
        fake.fails = true
        let memory = AylaMemoryModel(service: fake)
        memory.accept(memory.changes(in: suggestion), replyID: "r1", conversationID: "c1")
        await waitFor { memory.decision(for: suggestion) == .failed }
        #expect(memory.decision(for: suggestion) == .failed)
        #expect(memory.notes.isEmpty)
    }

    @Test func forgettingComesBackWhenItFails() async {
        let fake = FakeMemory()
        let note = AylaMemory(id: "m1", text: "Je studeert ICT.", source: .user, createdAt: .now)
        fake.stored = AylaMemories(notes: [note])
        let memory = AylaMemoryModel(service: fake, undoWindow: .milliseconds(10))
        await memory.load()
        fake.fails = true

        memory.forget(note)
        #expect(memory.notes.isEmpty)
        await waitFor { memory.problem != nil }

        #expect(memory.notes == [note])
        #expect(memory.problem == AylaMessages.memoryForgetFailed)
    }

    @Test func aForgottenNoteCanBeBroughtBackForAMoment() async throws {
        let fake = FakeMemory()
        let note = AylaMemory(id: "m1", text: "Je studeert ICT.", source: .user, createdAt: .now)
        fake.stored = AylaMemories(notes: [note])
        let memory = AylaMemoryModel(service: fake, undoWindow: .seconds(5))
        await memory.load()

        memory.forget(note)
        #expect(memory.notes.isEmpty)
        #expect(memory.pendingForget == note)
        memory.undoForget()
        try await Task.sleep(for: .milliseconds(30))

        #expect(memory.notes == [note])
        #expect(fake.forgotten.isEmpty)
    }

    @Test func aForgottenNoteIsReallyForgottenAfterTheWindow() async {
        let fake = FakeMemory()
        let note = AylaMemory(id: "m1", text: "Je studeert ICT.", source: .user, createdAt: .now)
        fake.stored = AylaMemories(notes: [note])
        let memory = AylaMemoryModel(service: fake, undoWindow: .milliseconds(10))
        await memory.load()
        memory.forget(note)
        await waitFor { !fake.forgotten.isEmpty }
        #expect(fake.forgotten == ["m1"])
        #expect(memory.pendingForget == nil)
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
