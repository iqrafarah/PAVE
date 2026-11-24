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
        /// An older server does not know a kind yet.
        var unknownKinds: Set<ApplicationWritingRequest.Kind> = []
        func writeApplication(_ request: ApplicationWritingRequest) async throws -> ApplicationWriting {
            requests.append(request)
            if unknownKinds.contains(request.kind) { throw AylaError.unavailable }
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
        #expect(first.stage == .gallery)
        first.update { $0.template = .night }
        let again = ApplicationStudioModel(vacancy: vacancy, items: [], name: "Iemand anders", email: "", service: nil, store: shared)
        #expect(again.draft.template == .night)
        #expect(again.draft.cv.name == "Daaf")
        #expect(again.stage == .editor)
    }

    @Test func aDesignFromTheGalleryBringsItsOwnColoursAndPhoto() {
        let model = ApplicationStudioModel(vacancy: vacancy, items: items(), name: "Daaf", email: "", service: nil, store: store)
        model.choose(.frame)
        #expect(model.stage == .start)
        #expect(model.draft.template == .frame)
        #expect(model.draft.palette == ApplicationTemplate.frame.palette)
        #expect(!model.draft.showsPhoto)
    }

    @Test func fillingItYourselfStartsWithTheVaultAndEmptyTexts() async {
        let model = ApplicationStudioModel(vacancy: vacancy, items: items(), name: "Daaf", email: "", service: Writer(), store: store)
        model.choose(.coral)
        model.update { $0.palette = .lavender }
        await model.begin(withAyla: false)
        #expect(model.stage == .editor)
        #expect(model.draft.template == .coral)
        #expect(model.draft.palette == .lavender)
        #expect(model.draft.cv.profile.isEmpty)
        #expect(!model.draft.cv.visibleSections.isEmpty)
        #expect(model.draft.letter.paragraphs.allSatisfy { $0.text.isEmpty })
    }

    @Test func aylaFillsTheProfileAndTheLetterAtOnce() async {
        let writer = Writer()
        writer.answer = ApplicationWriting(profile: "Ik bouw apps.", salutation: "Beste team van Appwerk,", paragraphs: [.init(text: "Bij Pixelwerk werkte ik met Swift.", sourceItemIDs: ["a"])], closing: "Met vriendelijke groet,")
        let model = ApplicationStudioModel(vacancy: vacancy, items: items(), name: "Daaf", email: "", service: writer, store: store)
        model.choose(.sage)
        await model.begin(withAyla: true)
        #expect(model.stage == .editor)
        #expect(model.draft.cv.profile == "Ik bouw apps.")
        #expect(model.draft.letter.paragraphs.map(\.text) == ["Bij Pixelwerk werkte ik met Swift."])
    }

    @Test func aylaWritesWhatYouDidInTheWordsOfACV() async {
        let writer = Writer()
        writer.answer = ApplicationWriting(
            profile: "Ik bouw apps.", headline: "Student HBO-ICT",
            entries: [.init(sourceItemID: "a", text: "Bouwde mee aan een iOS-app."), .init(sourceItemID: "b", text: "Mag ze niet zien.")],
            paragraphs: [.init(text: "Brief.")]
        )
        var items = items()
        items[0].description = "Je bouwde mee aan een iOS-app."
        items[1].description = "Je vulde vakken."
        let model = ApplicationStudioModel(vacancy: vacancy, items: items, name: "Daaf", email: "", service: writer, store: store)
        model.choose(.plain)
        await model.begin(withAyla: true)
        let entries = model.draft.cv.sections.first { $0.kind == .experience }?.entries ?? []
        #expect(entries.first { $0.sourceItemID == "a" }?.description == "Bouwde mee aan een iOS-app.")
        // What she may not see, she does not get and does not rewrite.
        #expect(entries.first { $0.sourceItemID == "b" }?.description == "Je vulde vakken.")
        #expect(writer.requests.first { $0.kind == .entries }?.items.map(\.id) == ["a"])
        #expect(model.draft.cv.headline == "Student HBO-ICT")
        #expect(model.writingEntries.isEmpty)
    }

    @Test func whenAylaCannotWriteTheEntriesTheVaultTextStays() async {
        let writer = Writer()
        writer.unknownKinds = [.entries]
        writer.answer = ApplicationWriting(profile: "Ik bouw apps.", paragraphs: [.init(text: "Brief.")])
        var items = items()
        items[0].description = "Je bouwde mee aan een iOS-app."
        let model = ApplicationStudioModel(vacancy: vacancy, items: items, name: "Daaf", email: "", service: writer, store: store)
        await model.begin(withAyla: true)
        #expect(model.draft.cv.sections.first?.entries.first { $0.sourceItemID == "a" }?.description == "Je bouwde mee aan een iOS-app.")
        #expect(model.problem == nil)
        #expect(model.draft.cv.profile == "Ik bouw apps.")
    }

    @Test func whatYouLeaveOutStaysOutAndAylaDoesNotWriteAboutIt() async {
        let writer = Writer()
        writer.answer = ApplicationWriting(profile: "Ik bouw apps.", paragraphs: [.init(text: "Brief.")])
        var items = items()
        items[1].aylaAllowedAt = .now
        let model = ApplicationStudioModel(vacancy: vacancy, items: items, name: "Daaf", email: "", service: writer, store: store)
        model.choose(.plain)
        #expect(model.isProposal)
        let bijbaan = model.draft.cv.sections.flatMap(\.entries).first { $0.sourceItemID == "b" }!
        model.setVisible(bijbaan.id, false)
        model.setFocus("Samenwerken")
        #expect(!model.isProposal)
        await model.begin(withAyla: true)
        let entries = model.draft.cv.sections.flatMap(\.entries)
        #expect(entries.first { $0.sourceItemID == "b" }?.isVisible == false)
        #expect(entries.first { $0.sourceItemID == "a" }?.isVisible == true)
        #expect(writer.requests.allSatisfy { $0.items.map(\.id) == ["a"] })
        #expect(writer.requests.first { $0.kind == .letter }?.focus == "Samenwerken")
        #expect(model.draft.focus == "Samenwerken")
    }

    @Test func theProposalLeavesOutTheLeastFittingUntilItIsOnePage() {
        var items = items()
        items.append(VaultItem(id: "c", category: .projects, title: "Project", organisationName: "Fontys"))
        let model = ApplicationStudioModel(vacancy: vacancy, items: items, name: "Daaf", email: "", service: nil, store: store)
        // A page holds two entries here.
        model.measure = { $0.cv.sections.flatMap(\.entries).filter(\.isVisible).count > 2 ? 2 : 1 }
        model.choose(.plain)
        let on = model.draft.cv.sections.flatMap(\.entries).filter(\.isVisible)
        #expect(on.count == 2)
        let off = model.draft.cv.sections.flatMap(\.entries).first { !$0.isVisible }!
        #expect(model.choices[off.id]?.reason == .forOnePage)
        // Nothing is kept before you begin.
        #expect(ApplicationStore(folder: URL.temporaryDirectory.appending(path: "nowhere")).load(vacancy.id) == nil)
        #expect(model.stage == .start)
    }

    @Test func typingShowsOnThePageAMomentLaterAndIsKeptWhenItSettles() async {
        let store = store
        let model = ApplicationStudioModel(vacancy: vacancy, items: items(), name: "Daaf", email: "", service: nil, store: store)
        await model.begin(withAyla: false)
        model.update(typing: true) { $0.cv.profile = "Ik" }
        model.update(typing: true) { $0.cv.profile = "Ik bouw" }
        #expect(model.draft.cv.profile == "Ik bouw")
        #expect(model.shown.cv.profile == "")
        #expect(store.load(vacancy.id)?.cv.profile == "")
        model.settle()
        #expect(model.shown.cv.profile == "Ik bouw")
        #expect(store.load(vacancy.id)?.cv.profile == "Ik bouw")
        model.update { $0.palette = .rose }
        #expect(model.shown.palette == .rose)
    }

    @Test func thePageMeasureCountsThePagesOfThePdf() throws {
        var draft = ApplicationBuilder.draft(for: vacancy, items: items(), name: "Daaf")
        #expect(ApplicationPageMeasure.pages(draft, photo: nil) == 1)
        draft.cv.profile = String(repeating: "Ik bouw apps die mensen echt gebruiken. ", count: 120)
        let pdf = try #require(PDFDocument(url: try ApplicationPDF.file(for: draft, document: .cv, photo: nil)))
        #expect(ApplicationPageMeasure.pages(draft, photo: nil) == pdf.pageCount)
        #expect(pdf.pageCount >= 2)
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
