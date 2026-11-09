import Foundation
import Testing
@testable import PAVECore

struct AylaReplyTests {
    private static let examples = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "shared/ayla/examples")

    private static var examplesAreAvailable: Bool {
        FileManager.default.fileExists(atPath: examples.path(percentEncoded: false))
    }

    @Test(.enabled(if: AylaReplyTests.examplesAreAvailable))
    func everySharedExampleCanBeRead() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.examples, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(files.count >= 6)
        for file in files {
            let reply = try AylaReply.decode(Data(contentsOf: file))
            #expect(reply.version == AylaReply.version, "\(file.lastPathComponent)")
            #expect(!reply.blocks.contains { if case .unknown = $0 { true } else { false } }, "\(file.lastPathComponent) has a block iOS cannot draw")
        }
    }

    @Test(.enabled(if: AylaReplyTests.examplesAreAvailable))
    func memoryExampleCarriesTheSuggestion() throws {
        let reply = try AylaReply.decode(Data(contentsOf: Self.examples.appending(path: "07-memory.json")))
        #expect(reply.suggestedMemories == [
            .init(text: "Je studeert ICT aan Fontys.", category: .education),
            .init(text: "Je werkt als leidinggevende bij de Plus.", category: .work),
        ])
    }

    @Test func anOlderSingleSuggestionAndUnknownCategoriesStillRead() throws {
        let old = try AylaReply.decode(Data(#"{"version":1,"id":"r","conversationId":"c","text":"Top","memory":{"text":"Je woont in Eindhoven."},"blocks":[],"usedData":[]}"#.utf8))
        #expect(old.suggestedMemories == [.init(text: "Je woont in Eindhoven.", category: .personal)])
        let new = try AylaReply.decode(Data(#"{"version":1,"id":"r","conversationId":"c","text":"Top","memories":[{"text":"Je voetbalt.","category":"sport"}],"blocks":[],"usedData":[]}"#.utf8))
        #expect(new.suggestedMemories.first?.category == .personal)
    }

    @Test(.enabled(if: AylaReplyTests.examplesAreAvailable))
    func vacanciesExampleKeepsEveryField() throws {
        let reply = try AylaReply.decode(Data(contentsOf: Self.examples.appending(path: "03-vacancies.json")))
        guard case .vacancies(let items) = reply.blocks.first else {
            Issue.record("expected vacancies")
            return
        }
        #expect(items.first?.salary?.isEstimate == true)
        #expect(items.first?.skillGap.first?.skill == "Scrum-certificaat")
        #expect(items.last?.salary == nil)
        #expect(reply.usedData == [.skills, .projects])
    }

    @Test func unknownBlockTypesAreSkippedNotFatal() throws {
        let json = #"{"version":1,"id":"r","conversationId":"c","text":"Hoi","blocks":[{"type":"timeline","steps":[]}],"usedData":["skills","somethingNew"]}"#
        let reply = try AylaReply.decode(Data(json.utf8))
        #expect(reply.blocks == [.unknown(type: "timeline")])
        #expect(reply.usedData == [.skills, VaultCategory(rawValue: "somethingNew")])
    }

    @Test func aReplySurvivesARoundTrip() throws {
        let reply = AylaReply(
            id: "r",
            conversationId: "c",
            text: "Hoi",
            question: .init(text: "Verder?", choices: [.init(id: "y", label: "Ja"), .init(id: "n", label: "Nee")]),
            proposedAction: .init(id: "a", kind: .draftProfile, summary: "Cv bewaren", expiresAt: Date(timeIntervalSince1970: 1_800_000_000)),
            blocks: [.cv(.init(profile: "p", experience: [.init(title: "t", organisation: "o", period: "2026")], skills: ["Swift"]))],
            navigation: .init(screen: .vault)
        )
        #expect(try AylaReply.decode(reply.encoded()) == reply)
    }

    @Test(arguments: [
        (Vacancy.Salary(min: 36000, max: 42000, period: .year, isEstimate: true), 3000...3500),
        (Vacancy.Salary(min: 3100, max: 2800, period: .month, isEstimate: false), 2800...3100),
    ])
    func salaryIsShownPerMonth(salary: Vacancy.Salary, expected: ClosedRange<Int>) {
        #expect(salary.monthlyRange == expected)
    }
}

@Suite(.serialized)
struct SupabaseAylaServiceTests {
    private let project = URL(string: "https://example.supabase.co")!

    private func service(token: String? = "token", respond: @escaping @Sendable (URLRequest) throws -> (Int, Data)) -> SupabaseAylaService {
        StubProtocol.handler = respond
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return SupabaseAylaService(projectURL: project, publishableKey: "publishable", session: URLSession(configuration: configuration)) { token }
    }

    private let request = AylaRequest(text: "Welke banen passen bij mij?", device: .phone, input: .text, context: .init(screen: .vault))

    @Test func sendsTheRequestWithTheUsersSession() async throws {
        let reply = #"{"version":1,"id":"r","conversationId":"c","text":"Hoi","blocks":[],"usedData":[]}"#
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (200, Data(reply.utf8))
        }
        let answer = try await ayla.send(request)
        #expect(answer.text == "Hoi")

        let sent = try #require(captured.request)
        #expect(sent.url?.absoluteString == "https://example.supabase.co/functions/v1/ayla")
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(sent.value(forHTTPHeaderField: "apikey") == "publishable")
        let body = try JSONSerialization.jsonObject(with: try #require(sent.bodyData)) as? [String: Any]
        #expect(body?["text"] as? String == request.text)
        #expect(body?["device"] as? String == "phone")
        #expect((body?["context"] as? [String: Any])?["screen"] as? String == "vault")
        #expect(body?["conversationId"] == nil)
        #expect(body?["attachments"] == nil)
    }

    @Test func addedFilesTravelAsTextWithTheQuestion() async throws {
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (200, Data(#"{"version":1,"id":"r","conversationId":"c","text":"Hoi","blocks":[],"usedData":[]}"#.utf8))
        }
        let file = try #require(AylaAttachment(name: "cv.pdf", text: "Stage   bij\n\n\nLiveWall"))
        _ = try await ayla.send(AylaRequest(text: "Kijk je mee?", device: .phone, input: .text, attachments: [file]))
        let body = try JSONSerialization.jsonObject(with: try #require(captured.request?.bodyData)) as? [String: Any]
        let attachments = try #require(body?["attachments"] as? [[String: String]])
        #expect(attachments == [["name": "cv.pdf", "text": "Stage bij\nLiveWall"]])
    }

    @Test func withoutASessionNothingIsSent() async {
        let ayla = service(token: nil) { _ in
            Issue.record("should not send")
            return (200, Data())
        }
        await #expect(throws: AylaError.notSignedIn) { try await ayla.send(request) }
    }

    @Test(arguments: [(401, AylaError.notSignedIn), (403, .insufficientAssurance), (404, .conversationNotFound), (502, .unavailable), (200, .unavailable)])
    func statusCodesBecomeErrors(status: Int, expected: AylaError) async {
        let ayla = service { _ in (status, Data("{}".utf8)) }
        await #expect(throws: expected) { try await ayla.send(request) }
    }

    @Test func networkProblemsAreNoConnection() async {
        let ayla = service { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: AylaError.noConnection) { try await ayla.send(request) }
    }
}

private final class Captured: @unchecked Sendable {
    var request: URLRequest?
}

private final class CapturedList: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { stored } }
    func append(_ request: URLRequest) { lock.withLock { stored.append(request) } }
}

private extension URLRequest {
    var bodyData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension SupabaseAylaServiceTests {
    @Test func conversationsAreReadWithTheUsersSession() async throws {
        let rows = #"[{"id":"c1","title":"Banen zoeken","updated_at":"2026-11-05T22:13:55.123456+00:00"}]"#
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (200, Data(rows.utf8))
        }
        let list = try await ayla.conversations()
        #expect(list.conversations.map(\.title) == ["Banen zoeken"])
        #expect(list.conversations.first?.updatedAt != .distantPast)
        #expect(list.canPin == false)
        let url = try #require(captured.request?.url?.absoluteString)
        #expect(url.hasPrefix("https://example.supabase.co/rest/v1/ayla_conversations?"))
        #expect(url.contains("order=updated_at.desc"))
        #expect(captured.request?.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }

    @Test func pinnedConversationsComeFirstOnceTheColumnExists() async throws {
        let rows = #"""
        [{"id":"a","title":"Banen zoeken","updated_at":"2026-11-05T22:00:00+00:00","pinned_at":null},
         {"id":"b","title":"Mijn cv","updated_at":"2026-11-01T10:00:00+00:00","pinned_at":"2026-11-02T09:00:00+00:00"}]
        """#
        let ayla = service { _ in (200, Data(rows.utf8)) }
        let list = try await ayla.conversations()
        #expect(list.canPin)
        #expect(list.pinned.map(\.id) == ["b"])
        #expect(list.others.map(\.id) == ["a"])
    }

    @Test func pinningUpdatesOnlyThatConversation() async throws {
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (204, Data())
        }
        try await ayla.setPinned(false, conversationID: "c1")
        let request = try #require(captured.request)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.absoluteString == "https://example.supabase.co/rest/v1/ayla_conversations?id=eq.c1")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        let body = try #require(request.bodyData)
        #expect(String(decoding: body, as: UTF8.self) == #"{"pinned_at":null}"#)
    }

    @Test func conversationsKnowWhereTheyBegan() async throws {
        let rows = #"[{"id":"c1","title":"Banen zoeken","updated_at":"2026-11-05T22:00:00+00:00","started_on":"web"}]"#
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (200, Data(rows.utf8))
        }
        let list = try await ayla.conversations(limit: 100)
        #expect(list.conversations.first?.startedOn == .web)
        #expect(captured.request?.url?.absoluteString.contains("limit=100") == true)
    }

    @Test func renamingUpdatesOnlyTheTitle() async throws {
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (200, Data(#"[{"id":"c1"}]"#.utf8))
        }
        try await ayla.rename("  Mijn   stage ", conversationID: "c1")
        let request = try #require(captured.request)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.absoluteString == "https://example.supabase.co/rest/v1/ayla_conversations?id=eq.c1&select=id")
        #expect(request.value(forHTTPHeaderField: "Prefer") == "return=representation")
        let body = try #require(request.bodyData)
        #expect(String(decoding: body, as: UTF8.self) == #"{"title":"Mijn stage"}"#)
    }

    @Test func anEmptyTitleIsNotSent() async throws {
        let ayla = service { _ in Issue.record("no request expected"); return (204, Data()) }
        await #expect(throws: AylaError.unavailable) { try await ayla.rename("   ", conversationID: "c1") }
    }

    @Test func deletingRemovesThatConversation() async throws {
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (200, Data(#"[{"id":"c1"}]"#.utf8))
        }
        try await ayla.delete(conversationID: "c1")
        let request = try #require(captured.request)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://example.supabase.co/rest/v1/ayla_conversations?id=eq.c1&select=id")
        #expect(request.value(forHTTPHeaderField: "Prefer") == "return=representation")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }

    @Test func aDeleteThatChangedNothingIsAFailure() async throws {
        let ayla = service { _ in (200, Data("[]".utf8)) }
        await #expect(throws: AylaError.conversationNotFound) { try await ayla.delete(conversationID: "c1") }
        await #expect(throws: AylaError.conversationNotFound) { try await ayla.rename("Nieuw", conversationID: "c1") }
    }

    @Test func theLastTurnIsRemovedWhenItIsAQuestionAndItsAnswer() async throws {
        let captured = CapturedList()
        let ayla = service { urlRequest in
            captured.append(urlRequest)
            return urlRequest.httpMethod == "DELETE"
                ? (200, Data(#"[{"id":"m2"},{"id":"m1"}]"#.utf8))
                : (200, Data(#"[{"id":"m2","role":"ayla"},{"id":"m1","role":"user"}]"#.utf8))
        }
        try await ayla.removeLastTurn(in: "c1")
        let requests = captured.requests
        #expect(requests.count == 2)
        let read = try #require(requests.first?.url?.absoluteString)
        #expect(read.contains("conversation_id=eq.c1"))
        #expect(read.contains("order=created_at.desc"))
        #expect(read.contains("limit=2"))
        #expect(requests.last?.httpMethod == "DELETE")
        #expect(requests.last?.url?.absoluteString == "https://example.supabase.co/rest/v1/ayla_messages?id=in.(m2,m1)&select=id")
    }

    @Test func nothingIsRemovedWhenTheLastTwoAreNotOneTurn() async throws {
        let captured = CapturedList()
        let ayla = service { urlRequest in
            captured.append(urlRequest)
            return (200, Data(#"[{"id":"m3","role":"ayla"},{"id":"m2","role":"ayla"}]"#.utf8))
        }
        await #expect(throws: AylaError.conversationNotFound) { try await ayla.removeLastTurn(in: "c1") }
        #expect(captured.requests.allSatisfy { $0.httpMethod == "GET" })
    }

    @Test func memoriesAndTheSettingAreReadTogether() async throws {
        let ayla = service { urlRequest in
            if urlRequest.url!.path().hasSuffix("ayla_settings") { return (200, Data(#"[{"memory_enabled":false}]"#.utf8)) }
            return (200, Data(#"[{"id":"m1","text":"Je studeert ICT.","source":"user","category":"education","created_at":"2026-11-09T10:00:00+00:00"}]"#.utf8))
        }
        let memories = try await ayla.memories()
        #expect(memories.isEnabled == false)
        #expect(memories.notes.map(\.text) == ["Je studeert ICT."])
        #expect(memories.notes.first?.source == .user)
        #expect(memories.notes.first?.category == .education)
    }

    @Test func withoutASettingTheMemoryIsOn() async throws {
        let ayla = service { _ in (200, Data("[]".utf8)) }
        #expect(try await ayla.memories() == AylaMemories(isEnabled: true, notes: []))
    }

    @Test func aMissingTableMeansNotSetUp() async {
        let ayla = service { _ in (404, Data(#"{"code":"PGRST205","message":"Could not find the table"}"#.utf8)) }
        await #expect(throws: AylaError.notSetUp) { try await ayla.memories() }
        await #expect(throws: AylaError.notSetUp) { try await ayla.forgetAllMemories() }
    }

    @Test func rememberingSavesTheTidyNoteWithItsConversation() async throws {
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (201, Data(#"[{"id":"m2","text":"Je hebt stage gelopen bij LiveWall.","source":"ayla","created_at":"2026-11-09T10:00:00+00:00"}]"#.utf8))
        }
        let memory = try await ayla.remember("  Je hebt stage gelopen\nbij LiveWall. ", category: .work, source: .ayla, conversationID: "c1")
        #expect(memory.id == "m2")
        let request = try #require(captured.request)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Prefer") == "return=representation")
        let body = try #require(request.bodyData)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json == ["text": "Je hebt stage gelopen bij LiveWall.", "source": "ayla", "category": "work", "conversation_id": "c1"])
    }

    @Test func beforeTheCategoryColumnExistsANoteIsSavedWithoutIt() async throws {
        let captured = CapturedList()
        let ayla = service { urlRequest in
            captured.append(urlRequest)
            let body = String(decoding: urlRequest.bodyData ?? Data(), as: UTF8.self)
            if body.contains("category") { return (400, Data(#"{"code":"PGRST204","message":"Could not find the 'category' column"}"#.utf8)) }
            return (201, Data(#"[{"id":"m3","text":"Je voetbalt.","source":"ayla","created_at":"2026-11-09T10:00:00+00:00"}]"#.utf8))
        }
        let memory = try await ayla.remember("Je voetbalt.", category: .interests, source: .ayla, conversationID: nil)
        #expect(captured.requests.count == 2)
        #expect(memory.category == .personal)
    }

    @Test func notesAreGroupedByCategory() {
        let memories = AylaMemories(notes: [
            AylaMemory(id: "1", text: "Je voetbalt.", category: .interests, source: .ayla, createdAt: .now),
            AylaMemory(id: "2", text: "Je studeert ICT.", category: .education, source: .ayla, createdAt: .now),
        ])
        #expect(memories.byCategory.map(\.category) == [.education, .interests])
    }

    @Test func forgettingEverythingDeletesOnlyWithAFilter() async throws {
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (204, Data())
        }
        try await ayla.forgetAllMemories()
        #expect(captured.request?.httpMethod == "DELETE")
        #expect(captured.request?.url?.absoluteString == "https://example.supabase.co/rest/v1/ayla_memories?id=not.is.null")
    }

    @Test func theSettingIsOneRowPerUser() async throws {
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (201, Data())
        }
        try await ayla.setMemoryEnabled(false)
        let request = try #require(captured.request)
        #expect(request.url?.absoluteString == "https://example.supabase.co/rest/v1/ayla_settings?on_conflict=user_id")
        #expect(request.value(forHTTPHeaderField: "Prefer") == "resolution=merge-duplicates,return=minimal")
    }

    @Test func aFactInOtherWordsIsKnown() {
        let memories = AylaMemories(notes: [AylaMemory(id: "m", text: "Je studeert ICT aan Fontys en werkt als leidinggevende bij de Plus.", source: .ayla, createdAt: .now)])
        #expect(memories.knows("Je werkt als leidinggevende bij de PLUS."))
        #expect(memories.knows("je studeert ICT op Fontys"))
        #expect(!memories.knows("Je wilt IT-consultant worden."))
    }

    @Test func notesAreTheSameWhateverTheCapitalsOrFullStop() {
        #expect(AylaMemory.isSame("Je studeert ICT.", "je studeert ict"))
        #expect(AylaMemory.clean("   ") == nil)
        #expect(AylaMemory.clean(String(repeating: "a", count: 400))?.count == AylaMemory.maxLength)
    }

    @Test func searchingLooksInTheMessages() async throws {
        let rows = #"[{"id":"m1","conversation_id":"c1","text":"Ik zoek een stage in de zorg"}]"#
        let captured = Captured()
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (200, Data(rows.utf8))
        }
        let hits = try await ayla.searchMessages("zorg*,")
        #expect(hits == [AylaSearchHit(id: "m1", conversationID: "c1", snippet: "Ik zoek een stage in de zorg")])
        let url = try #require(captured.request?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "text" }?.value == "ilike.*zorg*")
        #expect(url.path.hasSuffix("/ayla_messages"))
    }

    @Test func aSearchOfOneLetterIsNotSent() async throws {
        let ayla = service { _ in Issue.record("no request expected"); return (200, Data("[]".utf8)) }
        #expect(try await ayla.searchMessages("z").isEmpty)
    }

    @Test func aylasVoiceStreamsWithTheUsersSession() async throws {
        let captured = Captured()
        let audio = Data((0..<10_000).map { UInt8($0 % 256) })
        let ayla = service { urlRequest in
            captured.request = urlRequest
            return (200, audio)
        }
        var received = Data()
        for try await piece in ayla.speech(for: "Hoi Daaf") { received.append(piece) }
        #expect(received == audio)
        let request = try #require(captured.request)
        #expect(request.url?.absoluteString == "https://example.supabase.co/functions/v1/ayla-voice")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        let body = try JSONSerialization.jsonObject(with: try #require(request.bodyData)) as? [String: String]
        #expect(body == ["text": "Hoi Daaf"])
    }

    @Test func warmingUpOnlyWakesBothFunctions() async {
        let captured = CapturedList()
        let ayla = service { urlRequest in
            captured.append(urlRequest)
            return (200, Data("ok".utf8))
        }
        await ayla.warmUp()
        let requests = captured.requests
        #expect(Set(requests.compactMap(\.url?.absoluteString)) == [
            "https://example.supabase.co/functions/v1/ayla",
            "https://example.supabase.co/functions/v1/ayla-voice",
        ])
        #expect(requests.allSatisfy { $0.httpMethod == "OPTIONS" && $0.bodyData == nil })
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer token" })
    }

    @Test(arguments: [(401, AylaError.notSignedIn), (403, .insufficientAssurance), (502, .unavailable)])
    func aRefusedVoiceEndsWithAnError(status: Int, expected: AylaError) async {
        let ayla = service { _ in (status, Data()) }
        await #expect(throws: expected) {
            for try await _ in ayla.speech(for: "Hoi") {}
        }
    }

    @Test func pinningFailsLoudlyWhenSupabaseRefuses() async {
        let ayla = service { _ in (400, Data()) }
        await #expect(throws: AylaError.unavailable) { try await ayla.setPinned(true, conversationID: "c1") }
    }

    @Test func storedMessagesKeepTheirCards() async throws {
        let rows = #"""
        [{"id":"m1","role":"user","text":"Hoi","reply":null},
         {"id":"m2","role":"ayla","text":"Hallo","reply":{"version":1,"id":"r","conversationId":"c","text":"Hallo","blocks":[{"type":"vacancies","items":[]}],"usedData":[]}}]
        """#
        let ayla = service { _ in (200, Data(rows.utf8)) }
        let messages = try await ayla.messages(in: "c")
        #expect(messages.map(\.role) == [.user, .ayla])
        #expect(messages.last?.reply?.blocks == [.vacancies([])])
    }

    @Test func theUserIdComesFromTheSessionToken() {
        let payload = Data(#"{"sub":"7a1d6c1e-2f4b-4c8e-9d3a-1b2c3d4e5f60","aal":"aal2"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        #expect(SupabaseAylaService.subject(of: "x.\(payload).y") == "7a1d6c1e-2f4b-4c8e-9d3a-1b2c3d4e5f60")
        #expect(SupabaseAylaService.subject(of: "not-a-token") == nil)
    }
}

struct AylaAttachmentTests {
    @Test func aFileWithoutTextIsNotAdded() {
        #expect(AylaAttachment(name: "foto.jpg", text: " \n\t ") == nil)
    }

    @Test func longFilesAreCutToWhatAylaAccepts() throws {
        let file = try #require(AylaAttachment(name: String(repeating: "a", count: 300), text: String(repeating: "x", count: 30_000)))
        #expect(file.text.count == AylaAttachment.maxTextLength)
        #expect(file.name.count == AylaAttachment.maxNameLength)
    }
}

struct AylaConversationListTests {
    private let list = AylaConversationList(
        conversations: [
            AylaConversation(id: "a", title: "Softskills uitwerken", updatedAt: .init(timeIntervalSince1970: 10)),
            AylaConversation(id: "b", title: "Cv verbeteren", updatedAt: .init(timeIntervalSince1970: 20)),
        ],
        canPin: true
    )

    @Test func searchingIgnoresCaseAndAccents() {
        #expect(list.matching("CV").conversations.map(\.id) == ["b"])
        #expect(list.matching("sóftskills").conversations.map(\.id) == ["a"])
        #expect(list.matching("  ").conversations.count == 2)
    }

    @Test func pinningMovesAConversationToTheTop() {
        var list = list
        list.setPinned(true, id: "a", at: .init(timeIntervalSince1970: 30))
        #expect(list.pinned.map(\.id) == ["a"])
        #expect(list.others.map(\.id) == ["b"])
        list.setPinned(false, id: "a")
        #expect(list.pinned.isEmpty)
    }

    @Test func conversationsAreGroupedByWhenTheyWereLastUsed() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Amsterdam"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 21)))
        func ago(days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now)! }
        let list = AylaConversationList(
            conversations: [
                AylaConversation(id: "pin", title: "Vast", updatedAt: ago(days: 40), pinnedAt: ago(days: 1)),
                AylaConversation(id: "today", title: "Vandaag", updatedAt: ago(days: 0)),
                AylaConversation(id: "yesterday", title: "Gisteren", updatedAt: ago(days: 1)),
                AylaConversation(id: "week", title: "Week", updatedAt: ago(days: 6)),
                AylaConversation(id: "month", title: "Maand", updatedAt: ago(days: 20)),
                AylaConversation(id: "old", title: "Oud", updatedAt: ago(days: 90)),
            ],
            canPin: true
        )
        let sections = list.sections(now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["Vastgezet", "Vandaag", "Gisteren", "Afgelopen 7 dagen", "Afgelopen 30 dagen", "Eerder"])
        #expect(sections.map { $0.conversations.map(\.id) } == [["pin"], ["today"], ["yesterday"], ["week"], ["month"], ["old"]])
    }

    @Test func emptyGroupsAreLeftOut() {
        let sections = list.sections(now: .init(timeIntervalSince1970: 20))
        #expect(sections.map(\.kind) == [.today])
    }

    @Test func renamingAndRemovingChangeOnlyThatConversation() {
        var list = list
        list.rename(id: "a", to: "Mijn softskills")
        list.remove(id: "b")
        #expect(list.conversations.map(\.title) == ["Mijn softskills"])
    }

    @Test func aListWithOnlyInvisibleDifferencesLooksTheSame() {
        var echo = list
        echo.conversations[0].updatedAt = echo.conversations[0].updatedAt.addingTimeInterval(0.4)
        var pinned = list
        pinned.setPinned(true, id: "a", at: .init(timeIntervalSince1970: 30.25))
        var pinnedEcho = list
        pinnedEcho.setPinned(true, id: "a", at: .init(timeIntervalSince1970: 30))
        var renamed = list
        renamed.rename(id: "a", to: "Anders")
        let now = Date(timeIntervalSince1970: 100)
        #expect(list.looksTheSame(as: echo, now: now))
        #expect(pinned.looksTheSame(as: pinnedEcho, now: now))
        #expect(!list.looksTheSame(as: pinned, now: now))
        #expect(!list.looksTheSame(as: renamed, now: now))
    }

    @Test func typedTitlesAreTidiedUp() {
        #expect(AylaConversation.cleanTitle("  Mijn   stage \n bij LiveWall ") == "Mijn stage bij LiveWall")
        #expect(AylaConversation.cleanTitle("   ") == nil)
        #expect(AylaConversation.cleanTitle(String(repeating: "a", count: 200))?.count == AylaConversation.maxTitleLength)
    }
}

struct AylaRealtimeTests {
    @Test func theSocketUsesTheProjectAndKey() {
        let url = AylaRealtime.socketURL(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "key")
        #expect(url.absoluteString == "wss://example.supabase.co/realtime/v1/websocket?apikey=key&vsn=1.0.0")
    }

    @Test func joiningListensOnlyToTheUsersConversations() throws {
        let text = AylaRealtime.joinMessage(userID: "u1", accessToken: "jwt")
        let message = try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        #expect(message["event"] as? String == "phx_join")
        let payload = try #require(message["payload"] as? [String: Any])
        #expect(payload["access_token"] as? String == "jwt")
        let config = try #require(payload["config"] as? [String: Any])
        let changes = try #require(config["postgres_changes"] as? [[String: String]])
        #expect(changes == [["event": "*", "schema": "public", "table": "ayla_conversations", "filter": "user_id=eq.u1"]])
    }

    @Test func eventsAreRecognised() {
        #expect(AylaRealtime.event(in: #"{"event":"postgres_changes","payload":{}}"#) == .change)
        #expect(AylaRealtime.event(in: #"{"event":"phx_reply","payload":{"status":"ok"}}"#) == .joined)
        #expect(AylaRealtime.event(in: #"{"event":"phx_reply","payload":{"status":"error"}}"#) == .refused)
        #expect(AylaRealtime.event(in: #"{"event":"presence_state"}"#) == .other)
        #expect(AylaRealtime.event(in: "geen json") == .other)
    }
}

struct AylaSearchHitTests {
    @Test func theSnippetShowsTheTextAroundTheSearch() {
        let text = "Ik heb jarenlang in de horeca gewerkt en wil nu graag een stage zoeken in de zorg, liefst in Eindhoven of omgeving."
        let snippet = AylaSearchHit.snippet(of: text, around: "ZORG", width: 40)
        #expect(snippet.localizedCaseInsensitiveContains("zorg"))
        #expect(snippet.hasPrefix("…"))
        #expect(snippet.hasSuffix("…"))
    }

    @Test func aShortMessageIsShownWhole() {
        #expect(AylaSearchHit.snippet(of: "Mijn cv", around: "cv") == "Mijn cv")
    }
}

struct PCM16DecoderTests {
    @Test func samplesAreScaledToMinusOneAndOne() {
        var decoder = PCM16Decoder()
        let samples = decoder.samples(from: Data([0x00, 0x80, 0xFF, 0x7F, 0x00, 0x00]))
        #expect(samples == [-1, Float(32767) / 32768, 0])
    }

    @Test func aSampleSplitOverTwoPiecesIsKept() {
        var decoder = PCM16Decoder()
        #expect(decoder.samples(from: Data([0xFF, 0x7F, 0x00])) == [Float(32767) / 32768])
        #expect(decoder.samples(from: Data([0x80])) == [-1])
    }
}

struct AylaVoiceCueTests {
    @Test func captionsFollowTheSentences() {
        let text = "Hoi Ravi! Je stage telt mee. Wil je verder?"
        #expect(AylaCaptions.sentences(in: text) == ["Hoi Ravi!", "Je stage telt mee.", "Wil je verder?"])
        #expect(AylaCaptions.sentence(in: text, at: 0) == "Hoi Ravi!")
        #expect(AylaCaptions.sentence(in: text, at: 12) == "Je stage telt mee.")
        #expect(AylaCaptions.sentence(in: text, at: 500) == "Wil je verder?")
        #expect(AylaCaptions.sentence(in: "", at: 0) == nil)
    }

    @Test func numbersWithADotStayInOneSentence() {
        #expect(AylaCaptions.sentences(in: "Dat kost 2.500 euro. Prima.") == ["Dat kost 2.500 euro.", "Prima."])
    }

    @Test func wordsAboutPaveBringUpTheirIcon() {
        let cues = AylaVoiceCue.cues(in: "Hoi Daaf! In je kluis staan al drie diploma's, en daarna maken we samen een plan.")
        #expect(cues.map(\.icon) == [.hand, .kluis, .opleiding, .plan])
        #expect(cues.first?.at == 0)
        #expect(cues.allSatisfy { (0...1).contains($0.at) })
    }

    @Test func iconsNeverFollowEachOtherTooQuickly() {
        let cues = AylaVoiceCue.cues(in: "Je kluis en je plan staan klaar. Daarna kijken we rustig verder naar wat je nog wilt leren en doen.")
        #expect(cues.map(\.icon) == [.kluis])
        #expect(AylaVoiceCue.cues(in: "").isEmpty)
    }
}
