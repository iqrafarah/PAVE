import Foundation
import PDFKit
import Testing
@testable import PAVE
import PAVECore

@MainActor
struct ApplicationStudioTests {
    private final class Writer: AylaService, @unchecked Sendable {
        var answer = ApplicationWriting()
        var requests: [ApplicationWritingRequest] = []
        func writeApplication(_ request: ApplicationWritingRequest) async throws -> ApplicationWriting {
            requests.append(request)
            return answer
        }
        func send(_ request: AylaRequest) async throws -> AylaReply { throw AylaError.unavailable }
        func conversations(limit: Int) async throws -> AylaConversationList { AylaConversationList() }
        func rename(_ title: String, conversationID: String) async throws {}
        func delete(conversationID: String) async throws {}
        func searchMessages(_ text: String) async throws -> [AylaSearchHit] { [] }
        func conversationChanges() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
        func messages(in conversationID: String) async throws -> [AylaStoredMessage] { [] }
        func firstName() async -> String? { nil }
        func setPinned(_ isPinned: Bool, conversationID: String) async throws {}
        func removeLastTurn(in conversationID: String) async throws {}
    }

    private let vacancy = Vacancy(id: "v", title: "Junior iOS-ontwikkelaar", company: "Appwerk", source: .adzuna)
    private var store: ApplicationStore { ApplicationStore(folder: URL.temporaryDirectory.appending(path: "apply-\(UUID().uuidString)")) }

    private func items() -> [VaultItem] {
        var allowed = VaultItem(id: "a", category: .internships, title: "Eindstage", organisationName: "Pixelwerk", skills: ["Swift"])
        allowed.aylaAllowedAt = .now
        let hidden = VaultItem(id: "b", category: .workExperience, title: "Bijbaan", organisationName: "Supermarkt")
        return [allowed, hidden]
    }

    @Test func aylaOnlyGetsTheEvidenceSheMaySee() async {
        let writer = Writer()
        writer.answer = ApplicationWriting(profile: "Ik bouw apps met Swift.")
        let model = ApplicationStudioModel(vacancy: vacancy, items: items(), name: "Daaf", email: "", service: writer, store: store)
        await model.writeProfile()
        #expect(writer.requests.first?.items.map(\.id) == ["a"])
        #expect(model.draft.cv.profile == "Ik bouw apps met Swift.")
    }

    @Test func aRewriteCanBeUndoneOnce() async {
        let writer = Writer()
        let model = ApplicationStudioModel(vacancy: vacancy, items: items(), name: "Daaf", email: "", service: writer, store: store)
        model.update { $0.cv.profile = "Lange tekst over mij." }
        writer.answer = ApplicationWriting(text: "Korte tekst.")
        await model.rewrite(.profile, .shorter)
        #expect(model.draft.cv.profile == "Korte tekst.")
        #expect(writer.requests.last?.rewrite == .shorter)
        model.undoAyla()
        #expect(model.draft.cv.profile == "Lange tekst over mij.")
        #expect(model.before == nil)
    }

    @Test func aLetterFromAylaKeepsItsSources() async {
        let writer = Writer()
        writer.answer = ApplicationWriting(salutation: "Beste team van Appwerk,", paragraphs: [.init(text: "Bij Pixelwerk werkte ik met Swift.", sourceItemIDs: ["a"])], closing: "Met vriendelijke groet,")
        let model = ApplicationStudioModel(vacancy: vacancy, items: items(), name: "Daaf", email: "", service: writer, store: store)
        await model.writeLetter()
        #expect(model.draft.letter.paragraphs.map(\.sourceItemIDs) == [["a"]])
        #expect(model.draft.letter.salutation == "Beste team van Appwerk,")
    }

    @Test func aFailedWriteLeavesTheTextAndSaysSo() async {
        let model = ApplicationStudioModel(vacancy: vacancy, items: items(), name: "Daaf", email: "", service: Writer(), store: store)
        model.update { $0.cv.profile = "Mijn tekst." }
        await model.writeProfile()
        #expect(model.draft.cv.profile == "Mijn tekst.")
        #expect(model.problem == ApplyMessages.aylaFailed)
    }

    @Test func aDraftComesBackForTheSameVacancy() {
        let shared = store
        let first = ApplicationStudioModel(vacancy: vacancy, items: items(), name: "Daaf", email: "", service: nil, store: shared)
        first.update { $0.template = .bold }
        let again = ApplicationStudioModel(vacancy: vacancy, items: [], name: "Iemand anders", email: "", service: nil, store: shared)
        #expect(again.draft.template == .bold)
        #expect(again.draft.cv.name == "Daaf")
    }

    @Test func aLongCVBecomesMoreThanOneA4Page() throws {
        var draft = ApplicationBuilder.draft(for: vacancy, items: items(), name: "Daaf")
        draft.cv.profile = String(repeating: "Ik bouw apps die mensen echt gebruiken. ", count: 120)
        let url = try ApplicationPDF.file(for: draft, document: .cv, photo: nil)
        let pdf = try #require(PDFDocument(url: url))
        #expect(pdf.pageCount >= 2)
        let page = try #require(pdf.page(at: 0))
        #expect(page.bounds(for: .mediaBox).size == ApplicationPage.size)
        let text = pdf.string ?? ""
        #expect(text.contains("Daaf"))
    }

    @Test func aShortLetterIsOnePage() throws {
        let draft = ApplicationBuilder.draft(for: vacancy, items: items(), name: "Daaf")
        let pdf = try #require(PDFDocument(url: try ApplicationPDF.file(for: draft, document: .letter, photo: nil)))
        #expect(pdf.pageCount == 1)
        #expect((pdf.string ?? "").contains("Appwerk"))
    }
}
