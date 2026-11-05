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
        let conversations = try await ayla.conversations()
        #expect(conversations.map(\.title) == ["Banen zoeken"])
        #expect(conversations.first?.updatedAt != .distantPast)
        let url = try #require(captured.request?.url?.absoluteString)
        #expect(url.hasPrefix("https://example.supabase.co/rest/v1/ayla_conversations?"))
        #expect(url.contains("order=updated_at.desc"))
        #expect(captured.request?.value(forHTTPHeaderField: "Authorization") == "Bearer token")
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
