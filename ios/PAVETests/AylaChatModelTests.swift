import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct AylaChatModelTests {
    private final class FakeAyla: AylaService, @unchecked Sendable {
        var replies: [Result<AylaReply, AylaError>] = []
        var requests: [AylaRequest] = []

        func send(_ request: AylaRequest) async throws -> AylaReply {
            requests.append(request)
            return try replies.removeFirst().get()
        }

        func conversations() async throws -> [AylaConversation] { [] }
        func messages(in conversationID: String) async throws -> [AylaStoredMessage] { [] }
        func firstName() async -> String? { "Daaf" }
    }

    private func waitUntilIdle(_ model: AylaChatModel) async {
        for _ in 0..<200 where model.phase == .thinking {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func aReplyIsAddedAndTheConversationContinues() async {
        let ayla = FakeAyla()
        ayla.replies = [.success(AylaReply(id: "r1", conversationId: "conv", text: "Hoi Daaf")), .success(AylaReply(id: "r2", conversationId: "conv", text: "Prima"))]
        let model = AylaChatModel(service: ayla)

        model.send("Hoi")
        await waitUntilIdle(model)
        model.send("Hoe gaat het?")
        await waitUntilIdle(model)

        #expect(model.entries.map(\.text) == ["Hoi", "Hoi Daaf", "Hoe gaat het?", "Prima"])
        #expect(ayla.requests.first?.conversationId == nil)
        #expect(ayla.requests.last?.conversationId == "conv")
        #expect(ayla.requests.allSatisfy { $0.device == .phone })
    }

    @Test func aFailureShowsAMessageAndRetryDoesNotRepeatTheQuestion() async {
        let ayla = FakeAyla()
        ayla.replies = [.failure(.noConnection), .success(AylaReply(id: "r", conversationId: "c", text: "Daar ben ik"))]
        let model = AylaChatModel(service: ayla)

        model.send("Ben je er?")
        await waitUntilIdle(model)
        #expect(model.phase == .failed(AylaMessages.noConnection))

        model.retry()
        await waitUntilIdle(model)
        #expect(model.entries.map(\.text) == ["Ben je er?", "Daar ben ik"])
        #expect(model.phase == .idle)
    }

    @Test func choicesAreOfferedOnlyForTheLastReply() async {
        let ayla = FakeAyla()
        let question = AylaReply.Question(text: "Wil je iets toevoegen?", choices: [.init(id: "y", label: "Ja"), .init(id: "n", label: "Nee")])
        ayla.replies = [.success(AylaReply(id: "r", conversationId: "c", text: "Nog niets gevonden.", question: question))]
        let model = AylaChatModel(service: ayla)

        model.send("Staat mijn stage erin?")
        await waitUntilIdle(model)
        #expect(model.pendingQuestion == question)

        ayla.replies = [.success(AylaReply(id: "r2", conversationId: "c", text: "Top"))]
        model.send("Ja")
        await waitUntilIdle(model)
        #expect(model.pendingQuestion == nil)
    }

    @Test func emptyMessagesAreNotSent() {
        let ayla = FakeAyla()
        let model = AylaChatModel(service: ayla)
        model.send("   ")
        #expect(model.entries.isEmpty)
        #expect(ayla.requests.isEmpty)
    }

    @Test func withoutAylaNothingIsSent() {
        let model = AylaChatModel(service: nil)
        model.send("Hoi")
        #expect(!model.isAvailable)
        #expect(model.entries.isEmpty)
    }

    @Test func aNewConversationStartsEmpty() async {
        let ayla = FakeAyla()
        ayla.replies = [.success(AylaReply(id: "r", conversationId: "conv", text: "Hoi"))]
        let model = AylaChatModel(service: ayla)
        model.send("Hoi")
        await waitUntilIdle(model)

        model.newConversation()
        #expect(model.entries.isEmpty)
        #expect(model.conversationID == nil)
    }

    @Test func demoLoginHasNoAyla() {
        #expect(AylaServiceFactory.make(auth: MockAuthService()) == nil)
    }
}
