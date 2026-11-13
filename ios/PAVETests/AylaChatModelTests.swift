import Foundation
import PAVECore
import Testing
import UIKit
@testable import PAVE

@MainActor
struct AylaChatModelTests {
    /// The model calls the service from several tasks at once (pinning several chats), so every change to the records
    /// goes through the lock; without it the arrays could be written at the same moment and corrupt memory.
    private final class FakeAyla: AylaService, @unchecked Sendable {
        private let lock = NSLock()
        var replies: [Result<AylaReply, AylaError>] = []
        var requests: [AylaRequest] = []

        func send(_ request: AylaRequest) async throws -> AylaReply {
            try lock.withLock {
                requests.append(request)
                return try replies.removeFirst().get()
            }
        }

        var list = AylaConversationList()
        var pinFails = false
        var pinCalls: [(Bool, String)] = []

        var listFails = false
        var limits: [Int] = []
        var actionFails = false
        var renames: [(String, String)] = []
        var deletes: [String] = []
        var hits: [AylaSearchHit] = []

        func conversations(limit: Int) async throws -> AylaConversationList {
            try lock.withLock {
                limits.append(limit)
                if listFails { throw AylaError.noConnection }
                return list
            }
        }
        func rename(_ title: String, conversationID: String) async throws {
            try lock.withLock {
                renames.append((title, conversationID))
                if actionFails { throw AylaError.unavailable }
            }
        }
        func delete(conversationID: String) async throws {
            try lock.withLock {
                deletes.append(conversationID)
                if actionFails { throw AylaError.unavailable }
            }
        }
        func searchMessages(_ text: String) async throws -> [AylaSearchHit] { hits }
        var changes = AsyncStream<Void> { $0.finish() }
        func conversationChanges() -> AsyncStream<Void> { changes }
        var stored: [AylaStoredMessage] = []
        func messages(in conversationID: String) async throws -> [AylaStoredMessage] { stored }
        var nameDelay: Duration?
        func firstName() async -> String? {
            if let nameDelay { try? await Task.sleep(for: nameDelay) }
            return "Daaf"
        }
        func setPinned(_ isPinned: Bool, conversationID: String) async throws {
            try lock.withLock {
                pinCalls.append((isPinned, conversationID))
                if pinFails { throw AylaError.unavailable }
            }
        }
        var removedTurns: [String] = []
        func removeLastTurn(in conversationID: String) async throws {
            try lock.withLock {
                removedTurns.append(conversationID)
                if actionFails { throw AylaError.noConnection }
            }
        }
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

    @Test func aFailurePutsTheQuestionBackAndSendingAgainDoesNotRepeatIt() async {
        let ayla = FakeAyla()
        ayla.replies = [.failure(.noConnection), .success(AylaReply(id: "r", conversationId: "c", text: "Daar ben ik"))]
        let model = AylaChatModel(service: ayla)

        model.send("Ben je er?")
        await waitUntilIdle(model)
        #expect(model.phase == .failed(AylaMessages.noConnection))
        #expect(model.draft == "Ben je er?")

        model.send(model.draft)
        await waitUntilIdle(model)
        #expect(model.entries.map(\.text) == ["Ben je er?", "Daar ben ik"])
        #expect(model.phase == .idle)
    }

    @Test func anOfferToAddFromAylaGetsJaAndNeeLikeTheWeb() async {
        let ayla = FakeAyla()
        let skills = AylaBlock.skillSuggestions(itemId: "", skills: [.init(name: "Scrum", reason: "")])
        ayla.replies = [
            .success(AylaReply(id: "r1", conversationId: "c", text: "Die zie ik niet in je kluis.", blocks: [skills], navigation: .init(screen: .addEvidence))),
            .success(AylaReply(id: "r2", conversationId: "c", text: "Front-end past bij je.")),
        ]
        let model = AylaChatModel(service: ayla)

        model.send("Staat mijn Scrum-certificaat in de kluis?")
        await waitUntilIdle(model)
        #expect(model.pendingQuestion == AylaVaultOffer.question)
        #expect(model.pendingOffersEvidence)

        let flow = VaultAddEvidenceModel.proposed(by: model.lastReply, vault: VaultModel(service: nil))
        #expect(flow.skills == ["Scrum"])

        model.send("Welke richting past bij mij?")
        await waitUntilIdle(model)
        #expect(model.pendingQuestion == nil)
        #expect(!model.pendingOffersEvidence)
    }

    @Test func askingAboutAnItemSendsItWithEveryQuestionUntilANewConversation() async {
        let ayla = FakeAyla()
        ayla.replies = (1...3).map { .success(AylaReply(id: "r\($0)", conversationId: "c", text: "Oké")) }
        let model = AylaChatModel(service: ayla)
        model.ask(about: VaultItem(id: "item-1", category: .internships, title: "Eindstage"))
        #expect(model.contextTitle == "Eindstage")

        model.send("Wat laat dit zien?")
        await waitUntilIdle(model)
        model.send("En verder?")
        await waitUntilIdle(model)
        #expect(ayla.requests.map(\.context) == Array(repeating: AylaRequest.Context(screen: .vaultItem, itemId: "item-1"), count: 2))

        model.newConversation()
        #expect(model.contextTitle == nil)
        model.send("Hoi")
        await waitUntilIdle(model)
        #expect(ayla.requests.last?.context == nil)
    }

    @Test func anOpenPlaceOverTheChatIsTheContextUntilItCloses() async {
        let ayla = FakeAyla()
        ayla.replies = (1...2).map { .success(AylaReply(id: "r\($0)", conversationId: "c", text: "Oké")) }
        let model = AylaChatModel(service: ayla)

        model.showScreen(.vault)
        model.send("Wat staat erin?")
        await waitUntilIdle(model)
        #expect(ayla.requests.last?.context == AylaRequest.Context(screen: .vault))

        model.hideScreen(.vault)
        model.send("En verder?")
        await waitUntilIdle(model)
        #expect(ayla.requests.last?.context == nil)

        model.ask(about: VaultItem(id: "item-1", category: .internships, title: "Eindstage"))
        model.showScreen(.plans)
        model.hideScreen(.vaultItem)
        model.hideScreen(.plans)
        #expect(model.context == AylaRequest.Context(screen: .vaultItem, itemId: "item-1"))
    }

    @Test func aProposedItemFillsTheForm() {
        let item = AylaReply.VaultItemProposal(
            category: .internships, title: "Eindstage", organisationName: "LiveWall", startDate: "2025-02-01", isCurrent: true,
            description: "Je bouwde de front-end van drie campagnes.", skills: ["React", "Samenwerken"]
        )
        let reply = AylaReply(
            id: "r", conversationId: "c", text: "Zal ik je stage toevoegen?",
            proposedAction: AylaReply.ProposedAction(id: "a", kind: .addVaultItem, summary: "", expiresAt: .distantFuture, vaultItem: item)
        )
        let flow = VaultAddEvidenceModel.proposed(by: reply, vault: VaultModel(service: nil))
        #expect(flow.page == .details)
        #expect(flow.draft.category == .internships)
        #expect(flow.draft.title == "Eindstage")
        #expect(flow.draft.organisationName == "LiveWall")
        #expect(flow.draft.isCurrent)
        #expect(flow.draft.description == "Je bouwde de front-end van drie campagnes.")
        #expect(flow.skills == ["React", "Samenwerken"])
        #expect(flow.aylaFill == .idle)
        #expect(AylaVaultOffer.offersToAddEvidence(reply, asked: ""))
        // A proposal that is still growing has no full draft yet, but the card can show it.
        let growing = AylaReply.VaultItemProposal(category: .internships, title: "Stage", organisationName: "LiveWall")
        #expect(growing.partialDraft.organisationName == "LiveWall")
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

    @Test func aFileGoesWithTheNextMessageOnly() async throws {
        let ayla = FakeAyla()
        ayla.replies = [.success(AylaReply(id: "r1", conversationId: "c", text: "Gezien")), .success(AylaReply(id: "r2", conversationId: "c", text: "Oké"))]
        let model = AylaChatModel(service: ayla)
        let file = try #require(AylaAttachment(name: "cv.pdf", text: "Stage bij LiveWall"))

        model.attach(file)
        model.send("Kijk je mee?")
        #expect(model.attachments.isEmpty)
        await waitUntilIdle(model)
        model.send("Dank je")
        await waitUntilIdle(model)

        #expect(ayla.requests.map(\.attachments) == [[file], nil])
        #expect(model.entries.first?.attachments == ["cv.pdf"])
    }

    @Test func aFailureKeepsTheFileForTheNextTry() async throws {
        let ayla = FakeAyla()
        ayla.replies = [.failure(.noConnection), .success(AylaReply(id: "r", conversationId: "c", text: "Gezien"))]
        let model = AylaChatModel(service: ayla)
        let file = try #require(AylaAttachment(name: "cv.pdf", text: "Stage"))

        model.attach(file)
        model.send("Kijk je mee?")
        await waitUntilIdle(model)
        #expect(model.attachments == [file])

        model.send(model.draft)
        await waitUntilIdle(model)
        #expect(model.entries.map(\.text) == ["Kijk je mee?", "Gezien"])
        #expect(ayla.requests.last?.attachments == [file])
    }

    @Test func aSecondPhotoWithTheSameNameGetsANumber() throws {
        let model = AylaChatModel(service: FakeAyla())
        #expect(model.uniqueAttachmentName("Foto 2026-11-13.jpeg") == "Foto 2026-11-13.jpeg")
        model.attach(try #require(AylaAttachment(name: "Foto 2026-11-13.jpeg", text: "x")))
        #expect(model.uniqueAttachmentName("Foto 2026-11-13.jpeg") == "Foto 2026-11-13 2.jpeg")
        model.attach(try #require(AylaAttachment(name: "Foto 2026-11-13 2.jpeg", text: "x")))
        #expect(model.uniqueAttachmentName("Foto 2026-11-13.jpeg") == "Foto 2026-11-13 3.jpeg")
        #expect(model.attachments.count == 2)
    }

    @Test func aPhotoWithoutTextStillGoesAlong() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "werkplek.jpeg")
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        }
        try jpeg.write(to: url)
        let file = try await AttachmentReader.file(url)
        #expect(file.attachment.text == AylaAttachment.photoWithoutText)
        #expect(file.attachment.image?.isEmpty == false)
        #expect(file.upload?.mimeType == "image/jpeg")
    }

    @Test func aWebPageIsReadAsItsWords() {
        let html = "<html><head><style>p{color:red}</style><script>var x=1</script></head><body><h1>Testosteron</h1><p>Een &amp; twee&nbsp;drie.<br>Vier</p></body></html>"
        #expect(AttachmentReader.plainText(fromHTML: html) == "Testosteron\nEen & twee drie.\nVier")
    }

    @Test func filesOfAProposedItemAreReadOnceAndTheItemCanBeMarkedAdded() async throws {
        let ayla = FakeAyla()
        let item = AylaReply.VaultItemProposal(category: .certificates, title: "PSM I", attachments: ["cert.pdf"])
        let action = AylaReply.ProposedAction(id: "a", kind: .addVaultItem, summary: "", expiresAt: .distantFuture, vaultItem: item)
        ayla.replies = [
            .success(AylaReply(id: "r1", conversationId: "c", text: "Wanneer was dat?", proposedAction: action)),
            .success(AylaReply(id: "r2", conversationId: "c", text: "Zo zet ik het erin.", proposedAction: action)),
            .success(AylaReply(id: "r3", conversationId: "c", text: "Mooi!")),
        ]
        let model = AylaChatModel(service: ayla)
        var reads = 0
        let read = VaultEvidenceProposal(category: .certificates, title: "Professional Scrum Master I", organisationName: "Scrum.org")
        model.analyzeEvidence = { _ in reads += 1; return ([read], []) }
        let upload = VaultUpload(data: Data([1]), fileName: "cert.pdf", mimeType: "application/pdf")
        model.attach(try #require(AylaAttachment(name: "cert.pdf", text: "Scrum")), upload: upload)
        model.send("Zet dit in mijn kluis")
        await waitUntilIdle(model)
        var analysis = model.analysis(for: model.lastReply)
        while analysis?.isReading == true { await Task.yield(); analysis = model.analysis(for: model.lastReply) }
        #expect(analysis?.first == read)
        #expect(analysis?.uploads == [upload])

        model.send("In juni 2025")
        await waitUntilIdle(model)
        #expect(model.analysis(for: model.lastReply)?.first == read)
        #expect(reads == 1)

        model.markAdded(replyID: "r2", title: "PSM I", uploads: [upload])
        await waitUntilIdle(model)
        #expect(model.addedReplies.contains("r2"))
        #expect(model.conversationUploads.isEmpty)
        #expect(ayla.requests.last?.text == "Toegevoegd aan mijn kluis: PSM I.")
    }

    @Test func theOfferOnACardHidesJaAndNee() async {
        let ayla = FakeAyla()
        let question = AylaReply.Question(text: "Zet ik dit zo in je kluis?", choices: [.init(id: "y", label: "Ja"), .init(id: "n", label: "Nee")])
        let item = AylaReply.VaultItemProposal(category: .projects, title: "Designtest", organisationName: "MoofPlanner")
        let action = AylaReply.ProposedAction(id: "a", kind: .addVaultItem, summary: "", expiresAt: .distantFuture, vaultItem: item)
        ayla.replies = [.success(AylaReply(id: "r", conversationId: "c", text: "Zo zet ik het in je kluis.", question: question, proposedAction: action, navigation: .init(screen: .addEvidence)))]
        let model = AylaChatModel(service: ayla)
        model.send("Zet mijn project in de kluis")
        await waitUntilIdle(model)
        #expect(model.pendingQuestionIsOnCard)
        #expect(model.pendingOffersEvidence)
    }

    @Test func anItemFromThePlusButtonBecomesTheContextWithoutANewConversation() async {
        let ayla = FakeAyla()
        ayla.replies = [.success(AylaReply(id: "r1", conversationId: "c", text: "Hoi"))]
        let model = AylaChatModel(service: ayla)
        model.send("Hoi")
        await waitUntilIdle(model)
        model.attach(VaultItem(id: "item-1", category: .internships, title: "Eindstage"))
        #expect(model.entries.count == 2)
        #expect(model.context == AylaRequest.Context(screen: .vaultItem, itemId: "item-1"))
        #expect(model.contextTitle == "Eindstage")
    }

    @Test func aLoadedConversationShowsTheFilesAgain() async {
        let ayla = FakeAyla()
        ayla.stored = [AylaStoredMessage(id: "m1", role: .user, text: "Kijk je mee?", attachments: ["cv.pdf", "scan.pdf"]), AylaStoredMessage(id: "m2", role: .ayla, text: "Gezien")]
        let model = AylaChatModel(service: ayla)
        await model.open(AylaConversation(id: "c", title: "Cv", updatedAt: .now))
        #expect(model.entries.map(\.attachments) == [["cv.pdf", "scan.pdf"], []])
    }

    @Test func atMostFiveFilesAndNoDoubles() throws {
        let model = AylaChatModel(service: FakeAyla())
        let files = try ["a.pdf", "b.pdf", "c.pdf", "d.pdf", "e.pdf", "f.pdf"].map { try #require(AylaAttachment(name: $0, text: "x")) }
        #expect(model.attach(files[0]))
        #expect(model.attach(files[0]))
        #expect(model.attachments.count == 1)
        for file in files[1...4] { #expect(model.attach(file)) }
        #expect(!model.attach(files[5]))
        model.removeAttachment(files[1])
        #expect(model.attachments.map(\.name) == ["a.pdf", "c.pdf", "d.pdf", "e.pdf"])
    }

    @Test func theFilesOfTheLastQuestionCanGoIntoTheVault() async throws {
        let ayla = FakeAyla()
        ayla.replies = [.success(AylaReply(id: "r1", conversationId: "c", text: "Gezien")), .success(AylaReply(id: "r2", conversationId: "c", text: "Ook gezien"))]
        let model = AylaChatModel(service: ayla)
        let file = try #require(AylaAttachment(name: "cv.pdf", text: "Stage bij LiveWall"))
        let upload = VaultUpload(data: Data([1, 2]), fileName: "cv.pdf", mimeType: "application/pdf")
        let note = try #require(AylaAttachment(name: "notitie.txt", text: "x"))
        model.attach(file, upload: upload)
        model.attach(note)
        #expect(model.lastTurnUploads.isEmpty)
        model.send("Kijk je mee?")
        await waitUntilIdle(model)
        // Only files the vault can keep, and only those of the question just sent; the next message starts empty.
        #expect(model.lastTurnUploads == [upload])
        // Over the whole conversation the files stay, for evidence built up over several turns.
        model.send("En dit?")
        await waitUntilIdle(model)
        #expect(model.lastTurnUploads.isEmpty)
        #expect(model.conversationUploads == [upload])
        // Ayla names the files of an item; without names, the last question's files; never files of other evidence.
        #expect(model.uploads(for: .init(category: .projects, title: "App", attachments: ["cv.pdf"])) == [upload])
        // Names she gives that match nothing, or no names at all: the files of the item being built up.
        #expect(model.uploads(for: .init(category: .projects, title: "App", attachments: ["ander.pdf"])) == [upload])
        #expect(model.uploads(for: .init(category: .projects, title: "App")) == [upload])
        model.newConversation()
        #expect(model.conversationUploads.isEmpty)
        #expect(ayla.requests.first?.attachments?.map(\.name) == ["cv.pdf", "notitie.txt"])
    }

    @Test func pinningShowsAtOnceAndGoesBackWhenRefused() async {
        let ayla = FakeAyla()
        ayla.list = AylaConversationList(conversations: [AylaConversation(id: "c", title: "Cv", updatedAt: .now)], canPin: true)
        ayla.pinFails = true
        let model = AylaChatModel(service: ayla)
        await model.refreshConversations()

        model.togglePin(model.conversationList.conversations[0])
        #expect(model.conversationList.pinned.map(\.id) == ["c"])
        for _ in 0..<200 where !model.conversationList.pinned.isEmpty {
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(model.conversationList.pinned.isEmpty)
        #expect(ayla.pinCalls.map(\.0) == [true])
    }

    private func list(_ count: Int) -> AylaConversationList {
        AylaConversationList(
            conversations: (0..<count).map { AylaConversation(id: "c\($0)", title: "Chat \($0)", updatedAt: .now) },
            canPin: true
        )
    }

    private func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func renamingShowsAtOnceAndGoesBackWhenRefused() async {
        let ayla = FakeAyla()
        ayla.list = list(1)
        ayla.actionFails = true
        let model = AylaChatModel(service: ayla)
        await model.refreshConversations()

        model.rename(model.conversationList.conversations[0], to: "  Mijn   stage ")
        #expect(model.conversationList.conversations[0].title == "Mijn stage")
        await waitFor { model.chatsProblem != nil }
        #expect(model.conversationList.conversations[0].title == "Chat 0")
        #expect(model.chatsProblem == AylaMessages.renameFailed)
        #expect(ayla.renames.map(\.0) == ["Mijn stage"])
    }

    @Test func anEmptyOrUnchangedNameIsNotSent() async {
        let ayla = FakeAyla()
        ayla.list = list(1)
        let model = AylaChatModel(service: ayla)
        await model.refreshConversations()

        model.rename(model.conversationList.conversations[0], to: "   ")
        model.rename(model.conversationList.conversations[0], to: "Chat 0")
        try? await Task.sleep(for: .milliseconds(30))
        #expect(ayla.renames.isEmpty)
    }

    @Test func deletingTheOpenConversationStartsTheChatAfresh() async {
        let ayla = FakeAyla()
        ayla.list = list(2)
        ayla.replies = [.success(AylaReply(id: "r", conversationId: "c0", text: "Hoi"))]
        let model = AylaChatModel(service: ayla, undoWindow: .milliseconds(20))
        await model.refreshConversations()
        model.send("Hoi")
        await waitUntilIdle(model)
        #expect(model.conversationID == "c0")

        model.delete(model.conversationList.conversations[0])
        #expect(model.conversationList.conversations.map(\.id) == ["c1"])
        #expect(model.entries.isEmpty)
        #expect(model.conversationID == nil)
        await waitFor { !ayla.deletes.isEmpty }
        #expect(ayla.deletes == ["c0"])
    }

    @Test func aRefusedDeleteBringsTheConversationBack() async {
        let ayla = FakeAyla()
        ayla.list = list(2)
        ayla.actionFails = true
        let model = AylaChatModel(service: ayla, undoWindow: .milliseconds(20))
        await model.refreshConversations()

        model.delete(model.conversationList.conversations[1])
        #expect(model.conversationList.conversations.count == 1)
        await waitFor { model.chatsProblem != nil }
        #expect(model.conversationList.conversations.count == 2)
        #expect(model.chatsProblem == AylaMessages.deleteFailed)
    }

    @Test func undoingADeleteBringsTheChatsBackAndDeletesNothing() async {
        let ayla = FakeAyla()
        ayla.list = list(3)
        let model = AylaChatModel(service: ayla, undoWindow: .milliseconds(80))
        await model.refreshConversations()

        model.delete(Array(model.conversationList.conversations.prefix(2)))
        #expect(model.conversationList.conversations.map(\.id) == ["c2"])
        #expect(model.pendingDeletion.count == 2)
        model.undoDeletion()
        #expect(model.conversationList.conversations.count == 3)
        #expect(model.pendingDeletion.isEmpty)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(ayla.deletes.isEmpty)
    }

    @Test func aDeleteHappensAfterTheUndoWindowAndARefreshKeepsItHidden() async {
        let ayla = FakeAyla()
        ayla.list = list(2)
        let model = AylaChatModel(service: ayla, undoWindow: .milliseconds(150))
        await model.refreshConversations()

        model.delete(model.conversationList.conversations[0])
        await model.refreshConversations()
        #expect(model.conversationList.conversations.map(\.id) == ["c1"])
        #expect(ayla.deletes.isEmpty)
        await waitFor { !ayla.deletes.isEmpty }
        #expect(ayla.deletes == ["c0"])
        #expect(model.pendingDeletion.isEmpty)
    }

    @Test func goingAwayDeletesAtOnce() async {
        let ayla = FakeAyla()
        ayla.list = list(2)
        let model = AylaChatModel(service: ayla, undoWindow: .seconds(60))
        await model.refreshConversations()

        model.delete(model.conversationList.conversations[0])
        model.commitPendingDeletion()
        await waitFor { !ayla.deletes.isEmpty }
        #expect(ayla.deletes == ["c0"])
    }

    @Test func pinningSeveralPinsThemAllOrUnpinsWhenAllWerePinned() async {
        let ayla = FakeAyla()
        ayla.list = list(2)
        let model = AylaChatModel(service: ayla)
        await model.refreshConversations()

        model.togglePin(model.conversationList.conversations)
        #expect(model.conversationList.pinned.count == 2)
        model.togglePin(model.conversationList.conversations)
        #expect(model.conversationList.pinned.isEmpty)
    }

    @Test func aChangeOnTheServerRefreshesTheList() async {
        let ayla = FakeAyla()
        let (changes, continuation) = AsyncStream<Void>.makeStream()
        ayla.changes = changes
        let model = AylaChatModel(service: ayla)
        let following = Task { await model.followConversationChanges() }
        ayla.list = list(1)
        continuation.yield()
        await waitFor { model.conversationList.conversations.count == 1 }
        #expect(model.conversationList.conversations.count == 1)
        continuation.finish()
        await following.value
    }

    @Test func reachingTheEndLoadsMore() async {
        let ayla = FakeAyla()
        ayla.list = list(50)
        let model = AylaChatModel(service: ayla)
        await model.refreshConversations()
        #expect(model.canLoadMore)

        ayla.list = list(64)
        await model.loadMoreConversations()
        #expect(ayla.limits == [50, 100])
        #expect(model.conversationList.conversations.count == 64)
        #expect(!model.canLoadMore)
    }

    @Test func aFailedFirstLoadIsShownAndAFailedRefreshKeepsTheList() async {
        let ayla = FakeAyla()
        ayla.listFails = true
        let model = AylaChatModel(service: ayla)
        await model.refreshConversations()
        #expect(model.listFailed)

        ayla.listFails = false
        ayla.list = list(2)
        await model.refreshConversations()
        #expect(!model.listFailed)

        ayla.listFails = true
        await model.refreshConversations()
        #expect(!model.listFailed)
        #expect(model.conversationList.conversations.count == 2)
    }

    @Test func searchShowsEachConversationOnceAndOnlyKnownOnes() async {
        let ayla = FakeAyla()
        ayla.list = list(2)
        ayla.hits = [
            AylaSearchHit(id: "m1", conversationID: "c1", snippet: "stage in de zorg"),
            AylaSearchHit(id: "m2", conversationID: "c1", snippet: "nog meer zorg"),
            AylaSearchHit(id: "m3", conversationID: "gone", snippet: "zorg"),
        ]
        let model = AylaChatModel(service: ayla)
        await model.refreshConversations()

        let found = await model.searchMessages("zorg")
        #expect(found.map(\.hit.id) == ["m1"])
        #expect(found.first?.conversation.title == "Chat 1")
    }

    @Test func withoutThePinColumnNothingIsPinned() async {
        let ayla = FakeAyla()
        ayla.list = AylaConversationList(conversations: [AylaConversation(id: "c", title: "Cv", updatedAt: .now)], canPin: false)
        let model = AylaChatModel(service: ayla)
        await model.refreshConversations()

        model.togglePin(model.conversationList.conversations[0])
        #expect(model.conversationList.pinned.isEmpty)
        #expect(ayla.pinCalls.isEmpty)
    }

    @Test func aSpokenQuestionWaitsForTheAnswerAndStaysInTheChat() async {
        let ayla = FakeAyla()
        ayla.replies = [.success(AylaReply(id: "r", conversationId: "c", text: "Hoi Daaf"))]
        let model = AylaChatModel(service: ayla)

        let reply = await model.ask("Hoi Ayla", input: .voice)
        #expect(reply?.text == "Hoi Daaf")
        #expect(model.entries.map(\.text) == ["Hoi Ayla", "Hoi Daaf"])
        #expect(ayla.requests.first?.input == .voice)
        #expect(model.phase == .idle)
    }

    @Test func aFailedSpokenQuestionReturnsNothingAndShowsTheError() async {
        let ayla = FakeAyla()
        ayla.replies = [.failure(.noConnection)]
        let model = AylaChatModel(service: ayla)

        #expect(await model.ask("Hoi Ayla", input: .voice) == nil)
        #expect(model.phase == .failed(AylaMessages.noConnection))
    }

    @Test func demoLoginHasNoAyla() {
        #expect(AylaServiceFactory.make(auth: MockAuthService()) == nil)
    }

    @Test func theWelcomeWaitsForTheName() async {
        let model = AylaChatModel(service: FakeAyla())
        #expect(!model.isGreetingReady)
        await model.start()
        #expect(model.isGreetingReady)
        #expect(model.firstName == "Daaf")
    }

    @Test func aLateNameIsLeftOutSoTheWelcomeDoesNotJump() async throws {
        let ayla = FakeAyla()
        ayla.nameDelay = .milliseconds(300)
        let model = AylaChatModel(service: ayla, nameWait: .milliseconds(50))
        let starting = Task { await model.start() }
        try await Task.sleep(for: .milliseconds(150))
        #expect(model.isGreetingReady)
        #expect(model.firstName == nil)
        await starting.value
        #expect(model.firstName == nil)
    }

    private func answered(_ ayla: FakeAyla, replies: [String]) async -> AylaChatModel {
        ayla.replies = replies.map { .success(AylaReply(id: UUID().uuidString, conversationId: "c", text: $0)) }
        let model = AylaChatModel(service: ayla)
        model.send("Welke banen passen bij mij?")
        await waitUntilIdle(model)
        return model
    }

    @Test func askingAgainReplacesTheLastAnswer() async {
        let ayla = FakeAyla()
        let model = await answered(ayla, replies: ["Consultant", "Ontwikkelaar"])
        #expect(model.canRedoLastTurn)

        model.askAgain()
        await waitUntilIdle(model)

        #expect(ayla.removedTurns == ["c"])
        #expect(model.entries.map(\.text) == ["Welke banen passen bij mij?", "Ontwikkelaar"])
        #expect(ayla.requests.last?.text == "Welke banen passen bij mij?")
        #expect(ayla.requests.last?.conversationId == "c")
    }

    @Test func askingAgainKeepsTheAnswerWhenRemovingFails() async {
        let ayla = FakeAyla()
        let model = await answered(ayla, replies: ["Consultant"])
        ayla.actionFails = true

        model.askAgain()
        await waitUntilIdle(model)

        #expect(model.entries.map(\.text) == ["Welke banen passen bij mij?", "Consultant"])
        #expect(model.phase == .failed(AylaMessages.redoFailed))
        #expect(ayla.requests.count == 1)
    }

    @Test func editingPutsTheQuestionBackAndSendingWaitsForTheRemoval() async {
        let ayla = FakeAyla()
        let model = await answered(ayla, replies: ["Consultant", "Data-analist"])

        model.editLastQuestion()
        #expect(model.entries.isEmpty)
        #expect(model.draft == "Welke banen passen bij mij?")

        model.send("Welke banen met data passen bij mij?")
        await waitUntilIdle(model)

        #expect(ayla.removedTurns == ["c"])
        #expect(model.entries.map(\.text) == ["Welke banen met data passen bij mij?", "Data-analist"])
    }

    @Test func aFailedEditBringsTheTurnBack() async throws {
        let ayla = FakeAyla()
        let model = await answered(ayla, replies: ["Consultant"])
        ayla.actionFails = true

        model.editLastQuestion()
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.entries.map(\.text) == ["Welke banen passen bij mij?", "Consultant"])
        #expect(model.draft.isEmpty)
        #expect(model.phase == .failed(AylaMessages.redoFailed))
    }

    @Test func eachChatKeepsItsOwnDraft() async {
        let ayla = FakeAyla()
        let drafts = AylaDrafts()
        let model = AylaChatModel(service: ayla, drafts: drafts)
        model.draft = "Half getypt in een nieuwe chat"

        await model.open(AylaConversation(id: "a", title: "Mijn cv", updatedAt: .now))
        #expect(model.draft.isEmpty)
        model.draft = "Nog een vraag over mijn cv"

        model.newConversation()
        #expect(model.draft == "Half getypt in een nieuwe chat")

        await model.open(AylaConversation(id: "a", title: "Mijn cv", updatedAt: .now))
        #expect(model.draft == "Nog een vraag over mijn cv")
    }

    @Test func draftsSurviveARestartButNotSigningOut() throws {
        let defaults = try #require(UserDefaults(suiteName: "drafts-\(UUID().uuidString)"))
        AylaDrafts(defaults: defaults).save("Mijn vraag", for: "a")
        #expect(AylaDrafts(defaults: defaults)["a"] == "Mijn vraag")
        AylaDrafts.forget(in: defaults)
        #expect(AylaDrafts(defaults: defaults)["a"].isEmpty)
    }

    @Test func sendingClearsTheDraftOfThatChat() async {
        let ayla = FakeAyla()
        ayla.replies = [.success(AylaReply(id: "r", conversationId: "c", text: "Hoi"))]
        let drafts = AylaDrafts()
        let model = AylaChatModel(service: ayla, drafts: drafts)
        model.draft = "Hoi"
        model.send(model.draft)
        await waitUntilIdle(model)
        #expect(drafts[nil].isEmpty)
    }

    @Test func withoutAylaTheWelcomeShowsAtOnce() {
        #expect(AylaChatModel(service: nil).isGreetingReady)
    }
}
