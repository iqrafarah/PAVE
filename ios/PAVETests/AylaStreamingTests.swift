import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct AylaStreamingTests {
    /// Writes "Hoi", "Hoi Daaf" and then the reply, with a pause before the reply so a test can stop it.
    private final class WritingAyla: AylaService, @unchecked Sendable {
        var pauseBeforeReply: Duration = .zero
        var failsHalfway = false

        func send(_ request: AylaRequest) async throws -> AylaReply { throw AylaError.unavailable }
        func conversations(limit: Int) async throws -> AylaConversationList { AylaConversationList() }
        func messages(in conversationID: String) async throws -> [AylaStoredMessage] { [] }
        func setPinned(_ isPinned: Bool, conversationID: String) async throws {}
        func firstName() async -> String? { nil }

        func stream(_ request: AylaRequest) -> AsyncThrowingStream<AylaStreamEvent, any Error> {
            let pause = pauseBeforeReply
            let fails = failsHalfway
            return AsyncThrowingStream { continuation in
                let task = Task {
                    continuation.yield(.started(conversationID: "c1"))
                    continuation.yield(.text("Hoi"))
                    continuation.yield(.text("Hoi Daaf"))
                    if fails {
                        continuation.finish(throwing: AylaError.noConnection)
                        return
                    }
                    try? await Task.sleep(for: pause)
                    guard !Task.isCancelled else { return }
                    continuation.yield(.reply(AylaReply(id: "r1", conversationId: "c1", text: "Hoi Daaf, waar wil je mee beginnen?")))
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }

    private func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<300 where !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func theAnswerGrowsAndBecomesTheReply() async {
        let model = AylaChatModel(service: WritingAyla())
        model.send("Hoi")
        await waitFor { model.phase == .idle }
        #expect(model.entries.map(\.text) == ["Hoi", "Hoi Daaf, waar wil je mee beginnen?"])
        #expect(model.entries.last?.id == "r1")
        #expect(model.conversationID == "c1")
    }

    @Test func stoppingKeepsWhatWasWritten() async {
        let ayla = WritingAyla()
        ayla.pauseBeforeReply = .seconds(5)
        let model = AylaChatModel(service: ayla)
        model.send("Hoi")
        await waitFor { model.phase == .writing && model.entries.last?.text == "Hoi Daaf" }
        #expect(model.isAnswering)

        model.stopAnswer()
        await waitFor { model.phase == .idle }

        #expect(model.entries.map(\.text) == ["Hoi", "Hoi Daaf"])
        #expect(model.conversationID == "c1")
        #expect(!model.isAnswering)
    }

    @Test func aFailureHalfwayTakesTheHalfAnswerAway() async {
        let ayla = WritingAyla()
        ayla.failsHalfway = true
        let model = AylaChatModel(service: ayla)
        model.send("Hoi")
        await waitFor { if case .failed = model.phase { true } else { false } }
        #expect(model.entries.map(\.text) == ["Hoi"])
        #expect(model.draft == "Hoi")
    }

    @Test func nothingIsSentWhileAylaWrites() async {
        let ayla = WritingAyla()
        ayla.pauseBeforeReply = .seconds(5)
        let model = AylaChatModel(service: ayla)
        model.send("Hoi")
        await waitFor { model.phase == .writing }
        model.send("Nog iets")
        #expect(model.entries.filter { $0.role == .user }.count == 1)
        model.stopAnswer()
    }
}
