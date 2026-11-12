import Foundation
import Testing
@testable import PAVECore

private func token(aal: String = "aal2", expiresIn seconds: TimeInterval) -> String {
    let claims: [String: Any] = ["sub": "u1", "aal": aal, "exp": Date.now.addingTimeInterval(seconds).timeIntervalSince1970]
    let payload = try! JSONSerialization.data(withJSONObject: claims).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    return "header.\(payload).signature"
}

private let project = URL(string: "https://project.supabase.co")!

struct WatchSessionTests {
    @Test func aFreshTwoStepSessionIsUsable() {
        let session = WatchSession(projectURL: project, publishableKey: "pk", accessToken: token(expiresIn: 3600))
        #expect(session.isTwoStepVerified)
        #expect(session.isUsable())
        #expect(session.expiresAt != nil)
    }

    @Test func anAlmostExpiredOrSingleStepSessionIsNot() {
        #expect(!WatchSession(projectURL: project, publishableKey: "pk", accessToken: token(expiresIn: 60)).isUsable())
        #expect(!WatchSession(projectURL: project, publishableKey: "pk", accessToken: token(aal: "aal1", expiresIn: 3600)).isUsable())
        #expect(!WatchSession(projectURL: project, publishableKey: "pk", accessToken: "not-a-token").isUsable())
    }

    @Test func theLinkCarriesASessionOrSignsOut() throws {
        let session = WatchSession(projectURL: project, publishableKey: "pk", accessToken: token(expiresIn: 3600))
        #expect(WatchLink.update(from: WatchLink.message(for: session)) == .session(session))
        #expect(WatchLink.update(from: WatchLink.message(for: nil)) == .signedOut)
        #expect(WatchLink.update(from: WatchLink.message(for: session, isConnected: false)) == .notConnected)
        #expect(WatchLink.update(from: WatchLink.message(for: nil, isConnected: false)) == .signedOut)
        #expect(WatchLink.update(from: ["something": "else"]) == nil)
        #expect(WatchLink.isSessionRequest(WatchLink.sessionRequest))
        #expect(!WatchLink.isSessionRequest(["request": "other"]))
        // The refresh token never travels: only these three fields are in the message.
        let data = try #require(WatchLink.message(for: session)["session"] as? Data)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == ["projectURL", "publishableKey", "accessToken"])
    }
}

@Suite(.serialized)
struct AylaListenServiceTests {
    private func service(token: String? = "token", respond: @escaping @Sendable (URLRequest) -> (Int, Data)) -> SupabaseAylaListenService {
        ListenStub.handler = respond
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ListenStub.self]
        return SupabaseAylaListenService(projectURL: project, publishableKey: "pk", session: URLSession(configuration: configuration)) { token }
    }

    @Test func sendsTheRecordingAndReadsTheText() async throws {
        let listen = service { request in
            #expect(request.url?.path() == "/functions/v1/ayla-listen")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "audio/wav")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
            return (200, Data(#"{"text":"  Welke stage past bij mij? "}"#.utf8))
        }
        #expect(try await listen.transcribe(Data([1, 2, 3])) == "Welke stage past bij mij?")
    }

    @Test func mapsTheErrors() async {
        await #expect(throws: AylaError.notSignedIn) { try await service(token: nil) { _ in (200, Data()) }.transcribe(Data([1])) }
        await #expect(throws: AylaError.insufficientAssurance) { try await service { _ in (403, Data()) }.transcribe(Data([1])) }
        await #expect(throws: AylaError.notSetUp) { try await service { _ in (404, Data()) }.transcribe(Data([1])) }
        await #expect(throws: AylaError.unavailable) { try await service { _ in (200, Data()) }.transcribe(Data()) }
        let tooLong = Data(count: SupabaseAylaListenService.maximumBytes + 1)
        await #expect(throws: AylaError.unavailable) { try await service { _ in (200, Data()) }.transcribe(tooLong) }
    }
}

private final class ListenStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var request = request
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                body.append(buffer, count: read)
            }
            stream.close()
            request.httpBody = body
        }
        let (status, data) = Self.handler?(request) ?? (500, Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

struct AylaSpokenAnswerTests {
    @Test func shortClearAnswersCount() {
        #expect(AylaSpokenAnswer.interpret("Ja.") == true)
        #expect(AylaSpokenAnswer.interpret("  Ja, graag!") == true)
        #expect(AylaSpokenAnswer.interpret("Oké") == true)
        #expect(AylaSpokenAnswer.interpret("Nee, dank je.") == false)
        #expect(AylaSpokenAnswer.interpret("Liever niet") == false)
    }

    @Test func anythingElseIsANewQuestion() {
        #expect(AylaSpokenAnswer.interpret("Ja maar welke stage past bij mij?") == nil)
        #expect(AylaSpokenAnswer.interpret("Wat is een goede vacature?") == nil)
        #expect(AylaSpokenAnswer.interpret("") == nil)
    }
}

struct VaultProposalTests {
    @Test func aProposalBecomesADraftOnlyWhenItIsValid() throws {
        let json = #"{"version":1,"id":"r","conversationId":"c","text":"Zal ik je stage bij LiveWall in je kluis zetten?","blocks":[],"usedData":[],"proposedAction":{"id":"a1","kind":"addVaultItem","summary":"Stage bij LiveWall in je kluis zetten bij Stages","expiresAt":"2026-11-11T11:00:00Z","vaultItem":{"category":"internships","title":"Stage bij LiveWall","organisationName":"LiveWall","startDate":"2025-03-01","endDate":"2025-12-31"}}}"#
        let reply = try AylaReply.decode(Data(json.utf8))
        let action = try #require(reply.proposedAction)
        #expect(action.kind == .addVaultItem)
        #expect(action.isOpen(at: Date(timeIntervalSince1970: 0)))
        #expect(!action.isOpen(at: Date(timeIntervalSince1970: 2_000_000_000)))
        let draft = try #require(action.vaultItem?.draft)
        #expect(draft.category == .internships)
        #expect(draft.organisationName == "LiveWall")
        #expect(draft.startDate == VaultDay(year: 2025, month: 3, day: 1))
        #expect(draft.problem == nil)

        #expect(AylaReply.VaultItemProposal(category: AylaVaultCategory(rawValue: "pets"), title: "Hond").draft == nil)
        #expect(AylaReply.VaultItemProposal(category: .projects, title: "  ").draft == nil)
    }
}
