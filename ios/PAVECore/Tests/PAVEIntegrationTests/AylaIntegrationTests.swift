import Foundation
import PAVECore
import Testing

/// The `ayla` edge function: who it lets in, and a whole answer from question to stored conversation. Behind it is the
/// fake OpenRouter of ios/scripts/integration-tests.sh, so the answer is always the same and costs nothing.
@Suite(.localSupabase)
struct AylaIntegrationTests {
    /// What fake-openrouter.mjs always answers.
    static let fakeAnswer = "Hallo! Dit is een testantwoord van de nep-OpenRouter."

    private func events(_ service: SupabaseAylaService, _ text: String) async throws -> [AylaStreamEvent] {
        var events: [AylaStreamEvent] = []
        for try await event in service.stream(AylaRequest(text: text, device: .phone, input: .text)) {
            events.append(event)
        }
        return events
    }

    /// What the fake OpenRouter was asked: the last user message of each call.
    private func questionsTheModelGot() async throws -> [String] {
        let base = try #require(ProcessInfo.processInfo.environment["FAKE_OPENROUTER_URL"], "Run with ios/scripts/integration-tests.sh")
        let (data, _) = try await URLSession.shared.data(from: URL(string: "\(base)/requests")!)
        let requests = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return requests.compactMap { $0["userText"] as? String }
    }

    @Test func withoutAValidSessionAylaRefuses() async throws {
        let service = SupabaseAylaService(
            projectURL: LocalSupabase.url,
            publishableKey: LocalSupabase.publishableKey,
            accessToken: { "not-a-session" }
        )
        await #expect(throws: AylaError.notSignedIn) { try await events(service, "Hoi") }
    }

    @Test func withoutTwoStepVerificationAylaRefuses() async throws {
        let user = try await TestUser.make("aylaaal1", twoStep: false)
        await #expect(throws: AylaError.insufficientAssurance) { try await events(user.ayla, "Hoi") }
    }

    @Test func aQuestionGoesToTheModelAndTheAnswerIsStreamedAndStored() async throws {
        let user = try await TestUser.make("aylachat")
        let question = "Integratietest \(UUID().uuidString.prefix(8)): zeg hallo."
        let events = try await events(user.ayla, question)

        // The question reached the model.
        #expect(try await questionsTheModelGot().contains { $0.contains(question) })

        // The answer came back to the app: first the conversation, then the text while it was written, then the reply.
        let conversationID = try #require(events.compactMap { if case .started(let id) = $0 { id } else { nil } }.first)
        #expect(events.contains { if case .text(let text) = $0 { !text.isEmpty } else { false } })
        let reply = try #require(events.compactMap { if case .reply(let reply) = $0 { reply } else { nil } }.last)
        #expect(reply.text == Self.fakeAnswer)
        #expect(reply.conversationId == conversationID)

        // The conversation is stored under this account, with the question and the answer.
        #expect(try await user.ayla.conversations().conversations.contains { $0.id == conversationID })
        let messages = try await user.ayla.messages(in: conversationID)
        #expect(messages.contains { $0.text == question })
        #expect(messages.contains { $0.text == Self.fakeAnswer })
    }

    @Test func anotherAccountCannotOpenYourConversation() async throws {
        async let owner = TestUser.make("aylaowner")
        async let stranger = TestUser.make("aylastranger")
        let (a, b) = try await (owner, stranger)
        let events = try await events(a.ayla, "Iets persoonlijks.")
        let conversationID = try #require(events.compactMap { if case .started(let id) = $0 { id } else { nil } }.first)

        #expect(try await b.ayla.conversations().conversations.contains { $0.id == conversationID } == false)
    }
}
