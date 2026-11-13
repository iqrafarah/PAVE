import Foundation
import PAVECore
import Testing
import UIKit
@testable import PAVE

@MainActor
struct VaultAddEvidenceTests {
    /// Records what the flow sends and fails where a test asks it to.
    private actor FakeVault: VaultService {
        var added: [VaultItemDraft] = []
        var attached: [VaultFileRole] = []
        var skills: [[String]] = []
        var aylaAllowed: [String] = []
        var removedFiles: [String] = []
        var removedSkills: [[String]] = []
        var updated: [VaultItemDraft] = []
        var createdFolders: [String] = []
        var moved: [String: [String]] = [:]
        var failSkillsOnce = false
        var coverColumnExists = true
        var stored = VaultContents()

        func failNextSkills() { failSkillsOnce = true }
        func dropCoverColumn() { coverColumnExists = false }
        func store(_ contents: VaultContents) { stored = contents }

        func contents() async throws -> VaultContents { stored }

        func add(_ draft: VaultItemDraft) async throws -> String {
            added.append(draft)
            return "item-\(added.count)"
        }

        func attach(_ upload: VaultUpload, to itemID: String) async throws {
            if upload.role == .cover, !coverColumnExists { throw VaultError.missingColumn }
            attached.append(upload.role)
        }

        func fileData(_ file: VaultItem.File) async throws -> Data { Data() }

        func addSkills(_ names: [String], to itemID: String) async throws {
            if failSkillsOnce {
                failSkillsOnce = false
                throw VaultError.noConnection
            }
            skills.append(names)
        }

        func setAylaAllowed(_ allowed: Bool, itemID: String) async throws {
            if allowed { aylaAllowed.append(itemID) }
        }

        func removeFile(_ file: VaultItem.File) async throws { removedFiles.append(file.id) }
        func removeSkills(_ names: [String], from itemID: String) async throws { if !names.isEmpty { removedSkills.append(names) } }
        var material: [VaultSkillsMaterial] = []
        var proposals: [VaultEvidenceProposal] = []
        var readDocuments: [VaultEvidenceDocument] = []
        func propose(_ proposals: [VaultEvidenceProposal]) { self.proposals = proposals }
        func proposeEvidence(from documents: [VaultEvidenceDocument], folders: [String], known: [String]) async throws -> [VaultEvidenceProposal] {
            readDocuments = documents
            return proposals
        }
        func suggestSkills(for draft: VaultItemDraft, material: VaultSkillsMaterial, existing: [String], known: [String]) async throws -> [VaultSkillSuggestion] {
            self.material.append(material)
            return [VaultSkillSuggestion(name: "Presenteren", reason: "Je gaf een eindpresentatie")]
        }

        func update(_ draft: VaultItemDraft, itemID: String) async throws { updated.append(draft) }
        func setFolders(_ folderIDs: [String], itemID: String) async throws { moved[itemID] = folderIDs }
        func delete(_ item: VaultItem) async throws {}
        func createFolder(named name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> (folder: VaultFolder, styleSaved: Bool) {
            createdFolders.append(name)
            let folder = VaultFolder(id: "folder-\(name)", name: name, color: color, icon: icon)
            stored.folders.append(folder)
            return (folder, true)
        }
        func updateFolder(id: String, name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> Bool { true }
        func deleteFolder(id: String) async throws {}
        var orders: [[String]] = []
        var itemOrders: [[String]] = []
        func setItemOrder(_ itemIDs: [String]) async throws {
            guard orderColumnExists else { throw VaultError.missingColumn }
            itemOrders.append(itemIDs)
        }
        var orderColumnExists = true
        func dropOrderColumn() { orderColumnExists = false }
        func setFolderOrder(_ folderIDs: [String]) async throws {
            guard orderColumnExists else { throw VaultError.missingColumn }
            orders.append(folderIDs)
        }
    }

    private let pdf = VaultUpload(data: Data([1, 2, 3]), fileName: "LiveWall-eindstage-verslag.pdf", mimeType: "application/pdf")
    private let photo = VaultUpload(data: Data([1]), fileName: "Foto.jpeg", mimeType: "image/jpeg", role: .cover)

    private func filledFlow(_ service: FakeVault) async -> VaultAddEvidenceModel {
        let flow = VaultAddEvidenceModel(vault: VaultModel(service: service), category: .internships, folderID: nil)
        flow.pick(.success(pdf))
        await flow.next()
        flow.draft.organisationName = "LiveWall"
        flow.draft.startDate = VaultDay(year: 2025, month: 2, day: 1)
        flow.draft.description = "Front-end voor campagnes"
        await flow.next()
        return flow
    }

    private let certificate = VaultEvidenceProposal(
        category: .certificates, title: "Professional Scrum Master I", organisationName: "Scrum.org",
        issuedOn: VaultDay(year: 2025, month: 6, day: 12), description: "Certificaat voor Scrum.",
        skills: [VaultSkillSuggestion(name: "Scrum", reason: "Staat op het certificaat")], documents: [0],
        sources: ["title": "pagina 1", "period": "pagina 1"]
    )
    private let grades = VaultEvidenceProposal(category: .diplomas, title: "Cijferlijst", organisationName: "Fontys", documents: [1])
    private let second = VaultUpload(data: Data([9]), fileName: "cijferlijst.pdf", mimeType: "application/pdf")

    private func aylaFilled(_ proposals: [VaultEvidenceProposal], uploads: [VaultUpload]) async -> (VaultAddEvidenceModel, FakeVault) {
        let service = FakeVault()
        await service.propose(proposals)
        let flow = VaultAddEvidenceModel(vault: VaultModel(service: service), category: .projects, folderID: nil)
        for upload in uploads { flow.pick(.success(upload)) }
        flow.fillWithAyla()
        while flow.aylaFill == .reading { await Task.yield() }
        return (flow, service)
    }

    @Test func aylaFillsInWhatTheDocumentSays() async {
        let (flow, service) = await aylaFilled([certificate], uploads: [pdf])
        #expect(flow.aylaFill == .filled)
        #expect(flow.page == .details)
        #expect(flow.draft.title == "Professional Scrum Master I")
        #expect(flow.draft.category == .certificates)
        #expect(flow.draft.organisationName == "Scrum.org")
        #expect(flow.draft.issuedOn == VaultDay(year: 2025, month: 6, day: 12))
        #expect(flow.skills == ["Scrum"])
        #expect(flow.documents == [pdf])
        #expect(await service.readDocuments.count == 1)
        #expect(flow.aylaNote(for: .title) == "Door Ayla · pagina 1")
        #expect(flow.aylaNote(for: .organisation) == "Ingevuld door Ayla")
        flow.draft.title = "PSM I"
        #expect(flow.aylaNote(for: .title) == nil)
    }

    @Test func aProposalFromTheChatWithFilesStartsAylaReading() async {
        let service = FakeVault()
        await service.propose([certificate])
        let reply = AylaReply(
            id: "r", conversationId: "c", text: "Zal ik het toevoegen?",
            proposedAction: AylaReply.ProposedAction(id: "a", kind: .addVaultItem, summary: "", expiresAt: .distantFuture, vaultItem: .init(category: .certificates, title: "PSM I"))
        )
        let flow = VaultAddEvidenceModel.proposed(by: reply, vault: VaultModel(service: service), documents: [pdf])
        #expect(flow.documents == [pdf])
        #expect(flow.aylaFill == .reading)
        while flow.aylaFill == .reading { await Task.yield() }
        #expect(flow.aylaFill == .filled)
        #expect(flow.draft.title == "Professional Scrum Master I")
    }

    @Test func nothingFoundLeavesTheFormToYou() async {
        let (flow, _) = await aylaFilled([], uploads: [pdf])
        #expect(flow.aylaFill == .failed(VaultMessages.aylaFillEmpty))
        #expect(flow.page == .source)
        #expect(flow.aylaProposal == nil)
    }

    @Test func twoItemsStayOneUnlessYouAddThemApart() async {
        let (flow, _) = await aylaFilled([certificate, grades], uploads: [pdf, second])
        #expect(flow.aylaSplitTitles == ["Professional Scrum Master I", "Cijferlijst"])
        #expect(flow.documents == [pdf, second])
        #expect(flow.nextEvidence.isEmpty)

        flow.setAddsApart(true)
        #expect(flow.documents == [pdf])
        #expect(flow.nextEvidence.count == 1)
        let next = flow.nextFlow()
        #expect(next?.page == .details)
        #expect(next?.draft.title == "Cijferlijst")
        #expect(next?.documents == [second])
        #expect(next?.nextEvidence.isEmpty == true)
        #expect(next?.aylaSplitTitles == nil)

        flow.setAddsApart(false)
        #expect(flow.documents == [pdf, second])
        #expect(flow.nextEvidence.isEmpty)
        #expect(flow.nextFlow() == nil)
    }

    @Test func anotherFileUndoesTheSplitButKeepsTheFile() async {
        let (flow, _) = await aylaFilled([certificate, grades], uploads: [pdf, second])
        flow.setAddsApart(true)
        let extra = VaultUpload(data: Data([5]), fileName: "bijlage.png", mimeType: "image/png")
        flow.pick(.success(extra))
        #expect(flow.aylaSplitTitles == nil)
        #expect(flow.nextEvidence.isEmpty)
        #expect(flow.addsApart == false)
        #expect(flow.documents == [pdf, extra])
        #expect(flow.aylaNote(for: .title) != nil)
    }

    @Test func changingTheFilesWhileAylaReadsStopsHer() {
        let flow = VaultAddEvidenceModel(vault: VaultModel(service: FakeVault()), category: .projects, folderID: nil)
        flow.pick(.success(pdf))
        flow.fillWithAyla()
        #expect(flow.aylaFill == .reading)
        flow.remove(pdf)
        #expect(flow.aylaFill == .idle)
        #expect(flow.fillTask == nil)
    }

    @Test func aylaSeesThePageOfAPDFAndCutsOnlyWhatSheMarked() async throws {
        let page = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { context in
            context.beginPage()
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 30, y: 30, width: 120, height: 60))
            ("Certificaat Professional Scrum Master I, behaald op 12 juni 2025" as NSString)
                .draw(at: CGPoint(x: 40, y: 200), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        let certificate = VaultUpload(data: page, fileName: "psm.pdf", mimeType: "application/pdf")
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let photo = VaultUpload(data: jpeg, fileName: "uitreiking.jpeg", mimeType: "image/jpeg")
        let documents = await VaultEvidenceReader.read([certificate, photo]).documents
        #expect(documents[0].text?.contains("Scrum Master") == true)
        #expect(documents[0].image != nil)
        #expect(documents[1].image != nil)

        let box = VaultEvidenceProposal.Box(x: 0.04, y: 0.03, width: 0.22, height: 0.09)
        let logo = try #require(VaultAddEvidenceModel.part(of: [certificate], at: 0, box: box).flatMap(UIImage.init(data:)))
        #expect(abs(logo.size.width / logo.size.height - (0.22 * 595) / (0.09 * 842)) < 0.1)
        // A whole PDF page is a document, never a logo or a cover; a whole photo may be.
        #expect(VaultAddEvidenceModel.part(of: [certificate], at: 0, box: nil) == nil)
        #expect(VaultAddEvidenceModel.part(of: [photo], at: 0, box: nil) != nil)
        #expect(VaultAddEvidenceModel.part(of: [photo], at: 3, box: nil) == nil)
    }

    @Test func documentsAreCountedAgainForTheNextItem() {
        let proposal = VaultEvidenceProposal(category: .projects, title: "Project", documents: [2, 4], coverDocument: 4, logoDocument: 1)
        let renumbered = VaultAddEvidenceModel.renumbered(proposal, to: [2, 4])
        #expect(renumbered.documents == [0, 1])
        #expect(renumbered.coverDocument == 1)
        #expect(renumbered.logoDocument == nil)
    }

    @Test func aFileGivesTheTitleAFirstGuess() async {
        let flow = VaultAddEvidenceModel(vault: VaultModel(service: FakeVault()), category: .projects, folderID: nil)
        flow.pick(.success(pdf))
        #expect(flow.draft.title == "LiveWall eindstage verslag")
        // You stay at the first step, so you can add another file before going on.
        #expect(flow.page == .source)
        flow.pick(.success(pdf))
        #expect(flow.documents.count == 1)
        flow.pick(.success(VaultUpload(data: Data([7]), fileName: "bijlage.png", mimeType: "image/png")))
        #expect(flow.documents.count == 2)
        await flow.next()
        #expect(flow.page == .details)
    }

    @Test func theFormStopsAtEmptyFields() async {
        let flow = VaultAddEvidenceModel(vault: VaultModel(service: FakeVault()), category: .projects, folderID: nil)
        flow.withoutFile()
        await flow.next()
        #expect(flow.page == .details)
        #expect(flow.missingFields == [.title, .organisation, .period, .description])
    }

    @Test func aCoverNeedsAPhoto() async {
        let flow = await filledFlow(FakeVault())
        #expect(flow.page == .documents)
        flow.wantsCover = true
        await flow.next()
        #expect(flow.page == .documents)
        #expect(flow.problem == VaultMessages.coverMissing)
        flow.pick(.success(photo))
        await flow.next()
        #expect(flow.page == .skills)
    }

    @Test func savesEverythingOnceAndRetriesOnlyWhatFailed() async {
        let service = FakeVault()
        await service.failNextSkills()
        let flow = await filledFlow(service)
        flow.wantsCover = true
        flow.pick(.success(photo))
        await flow.next()
        flow.toggle("Figma")
        flow.addOwnSkill("figma")
        flow.addOwnSkill("Samenwerken")
        #expect(flow.skills == ["Figma", "Samenwerken"])

        await flow.next()
        #expect(flow.page == .skills)
        #expect(flow.problem != nil)
        #expect(!flow.canGoBack)

        await flow.next()
        #expect(flow.page == .done)
        #expect(await service.added.count == 1)
        #expect(await service.attached == [.document, .cover])
        #expect(await service.skills == [["Figma", "Samenwerken"]])
    }

    @Test func everyDocumentIsSavedOnce() async {
        let service = FakeVault()
        let flow = await filledFlow(service)
        flow.pick(.success(VaultUpload(data: Data([9]), fileName: "certificaat.png", mimeType: "image/png")))
        flow.pick(.success(VaultUpload(data: Data([9]), fileName: "certificaat.png", mimeType: "image/png")))
        #expect(flow.documents.count == 2)
        await flow.next()
        await flow.next()
        #expect(flow.page == .done)
        #expect(await service.attached == [.document, .document])
    }

    @Test func aCoverWaitsForTheMigration() async {
        let service = FakeVault()
        await service.dropCoverColumn()
        let flow = await filledFlow(service)
        flow.wantsCover = true
        flow.pick(.success(photo))
        await flow.next()
        await flow.next()
        #expect(flow.page == .done)
        #expect(flow.coverWaits)
        #expect(await service.attached == [.document])
    }

    @Test func aylaOnlyGetsInWhenTicked() async {
        let service = FakeVault()
        let flow = await filledFlow(service)
        await flow.next()
        await flow.next()
        #expect(await flow.finish())
        #expect(await service.aylaAllowed.isEmpty)

        let second = await filledFlow(service)
        await second.next()
        await second.next()
        second.allowsAyla = true
        #expect(await second.finish())
        #expect(await service.aylaAllowed == ["item-2"])
    }

    private func vaultWithFolders(_ service: FakeVault) async -> VaultModel {
        await service.store(VaultContents(
            items: [VaultItem(id: "i", folderIDs: ["a", "c"], category: .projects, title: "App")],
            folders: [VaultFolder(id: "a", name: "A"), VaultFolder(id: "b", name: "B"), VaultFolder(id: "c", name: "C")]
        ))
        let model = VaultModel(service: service)
        await model.load()
        return model
    }

    @Test func draggingOutOfAFolderMovesButFromTheVaultOnlyAdds() async {
        let service = FakeVault()
        let model = await vaultWithFolders(service)
        let item = model.items[0]
        await model.move(item, to: model.folders[1], from: "a")
        #expect(await service.moved["i"] == ["c", "b"])
        await model.move(item, to: model.folders[1], from: nil)
        #expect(await service.moved["i"] == ["a", "c", "b"])
    }

    @Test func aDroppedFolderTakesThePlaceOfTheOther() async {
        UserDefaults.standard.removeObject(forKey: "vaultFolderOrder")
        defer { UserDefaults.standard.removeObject(forKey: "vaultFolderOrder") }
        let service = FakeVault()
        let model = await vaultWithFolders(service)
        await model.moveFolder("c", onto: "a")
        #expect(model.folders.map(\.id) == ["c", "a", "b"])
        #expect(await service.orders == [["c", "a", "b"]])

        // Without the column the order stays on this device and survives loading again.
        await service.dropOrderColumn()
        await model.moveFolder("b", onto: "c")
        await model.load()
        #expect(model.folders.map(\.id) == ["b", "c", "a"])
    }

    @Test func draggedCardsKeepTheirOrderAroundTheOthers() async {
        UserDefaults.standard.removeObject(forKey: "vaultItemOrder")
        defer { UserDefaults.standard.removeObject(forKey: "vaultItemOrder") }
        let service = FakeVault()
        let day = { (d: Int) in VaultDay(year: 2025, month: 1, day: d) }
        await service.store(VaultContents(items: [
            VaultItem(id: "a", folderIDs: ["f"], category: .projects, title: "A", issuedOn: day(4)),
            VaultItem(id: "b", category: .projects, title: "B", issuedOn: day(3)),
            VaultItem(id: "c", folderIDs: ["f"], category: .projects, title: "C", issuedOn: day(2)),
            VaultItem(id: "d", category: .projects, title: "D", issuedOn: day(1)),
        ]))
        let model = VaultModel(service: service)
        await model.load()
        // In folder f only a and c show: c goes first, and b and d keep their places.
        await model.setItemOrder(["c", "a"])
        #expect(await service.itemOrders == [["c", "b", "a", "d"]])
        var custom = VaultFilter()
        custom.order = .custom
        #expect(custom.apply(to: model.items).map(\.id) == ["c", "b", "a", "d"])

        await service.dropOrderColumn()
        await model.setItemOrder(["d", "c"])
        await model.load()
        #expect(custom.apply(to: model.items).map(\.id) == ["d", "b", "a", "c"])
    }

    @Test func aClosedDraftComesBackForHalfAMinuteOnce() {
        let model = VaultModel(service: FakeVault())
        let flow = VaultAddEvidenceModel(vault: model, category: .projects, folderID: nil)
        let start = Date.now
        model.keepDraft(flow, now: start)
        #expect(model.takeDraft(now: start) == nil)

        flow.draft.title = "Eindstage"
        model.keepDraft(flow, now: start)
        let back = model.takeDraft(now: start.addingTimeInterval(20))
        #expect(back === flow)
        #expect(back?.isResumed == true)
        #expect(model.takeDraft(now: start.addingTimeInterval(21)) == nil)

        model.keepDraft(flow, now: start)
        #expect(model.takeDraft(now: start.addingTimeInterval(31)) == nil)
    }

    @Test func anAccountWithoutFoldersGetsTheExampleFoldersOnce() async {
        UserDefaults.standard.removeObject(forKey: VaultModel.exampleFoldersKey)
        defer { UserDefaults.standard.removeObject(forKey: VaultModel.exampleFoldersKey) }
        let service = FakeVault()
        await service.store(VaultContents(items: [
            VaultItem(id: "p", category: .projects, title: "App"),
            VaultItem(id: "s", category: .internships, title: "Stage"),
        ]))
        let model = VaultModel(service: service)
        await model.load()
        #expect(await service.createdFolders == ["Certificaten", "Diploma's", "Feedback", "Projecten"])
        #expect(await service.moved == ["p": ["folder-Projecten"]])
        await service.store(VaultContents())
        await model.load()
        #expect(await service.createdFolders.count == 4)
    }

    @Test func aNewItemGoesInTheFolderOfItsKindAndWhereYouAreUntilYouChoose() async {
        let service = FakeVault()
        await service.store(VaultContents(folders: [
            VaultFolder(id: "c", name: "Certificaten"),
            VaultFolder(id: "p", name: "Projecten"),
            VaultFolder(id: "s", name: "Stage"),
        ]))
        let vault = VaultModel(service: service)
        await vault.load()

        let flow = VaultAddEvidenceModel(vault: vault, category: .projects, folderID: nil)
        #expect(flow.draft.folderIDs == ["p"])
        flow.draft.category = .certificates
        flow.categoryChanged()
        #expect(flow.draft.folderIDs == ["c"])

        let fromStage = VaultAddEvidenceModel(vault: vault, category: .projects, folderID: "s")
        #expect(fromStage.draft.folderIDs == ["s", "p"])
        fromStage.draft.category = .certificates
        fromStage.categoryChanged()
        #expect(fromStage.draft.folderIDs == ["s", "c"])
        fromStage.draft.folderIDs.removeAll { $0 == "c" }
        fromStage.folderChosen()
        fromStage.draft.category = .projects
        fromStage.categoryChanged()
        #expect(fromStage.draft.folderIDs == ["s"])
    }

    @Test func aKindWithoutAFolderGetsOneWhenSavingUnlessUnticked() async {
        let service = FakeVault()
        let flow = await filledFlow(service)
        #expect(flow.newKindFolder == "Stages")
        await flow.next()
        await flow.next()
        #expect(flow.page == .done)
        #expect(await service.createdFolders == ["Stages"])
        #expect(await service.added.first?.folderIDs == ["folder-Stages"])

        let other = FakeVault()
        let unticked = await filledFlow(other)
        unticked.setMakesKindFolder(false)
        await unticked.next()
        await unticked.next()
        #expect(await !other.createdFolders.contains("Stages"))
        #expect(await other.added.first?.folderIDs == [])
    }

    @Test func changingAConfirmedItemAsksAndSavesOnlyWhatChanged() async {
        let service = FakeVault()
        let report = VaultItem.File(id: "f1", name: "verslag.pdf", mimeType: "application/pdf", storagePath: "u/i/f1.pdf")
        let item = VaultItem(id: "i", category: .internships, title: "Stage", status: .verified, skills: ["Figma", "Scrum"], files: [report])
        let vault = VaultModel(service: service)
        let edit = VaultEditEvidenceModel(vault: vault, item: item)
        #expect(!edit.hasChanges)
        edit.skills = ["Figma", "Presenteren"]
        edit.allowsAyla = true
        #expect(edit.hasChanges)
        #expect(!edit.needsReconfirmation)
        edit.remove(report)
        edit.pick(.success(VaultUpload(data: Data([1]), fileName: "nieuw.png", mimeType: "image/png")))
        #expect(edit.needsReconfirmation)
        #expect(await edit.save())
        #expect(await service.updated.isEmpty)
        #expect(await service.removedFiles == ["f1"])
        #expect(await service.attached == [.document])
        #expect(await service.skills == [["Presenteren"]])
        #expect(await service.removedSkills == [["Scrum"]])
        #expect(await service.aylaAllowed == ["i"])
    }

    @Test func aylaProposesSkillsOnlyWhenAsked() async {
        let ayla = VaultAylaSkills(vault: VaultModel(service: FakeVault()))
        #expect(ayla.state == .idle)
        await ayla.ask(for: VaultItemDraft(category: .projects), chosen: [])
        #expect(ayla.state == .loaded([VaultSkillSuggestion(name: "Presenteren", reason: "Je gaf een eindpresentatie")]))
    }

    @Test func aylaLooksAtTheTextOfAPDFAndAPhotoOfAnImage() async {
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { context in
            context.beginPage()
            ("Stageverslag LiveWall: ik bouwde de front-end van drie campagnes in React." as NSString)
                .draw(at: CGPoint(x: 40, y: 40), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        let large = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1500)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
        }
        let service = FakeVault()
        let flow = VaultAddEvidenceModel(vault: VaultModel(service: service), category: .internships, folderID: nil)
        flow.pick(.success(VaultUpload(data: pdf, fileName: "verslag.pdf", mimeType: "application/pdf")))
        flow.pick(.success(VaultUpload(data: large, fileName: "certificaat.jpeg", mimeType: "image/jpeg")))
        flow.draft.title = "Eindstage"

        await flow.ayla.ask(for: flow.draft, chosen: [])
        let material = await service.material.first
        #expect(material?.texts.first?.text.contains("front-end van drie campagnes") == true)
        #expect(material?.images.map(\.name) == ["certificaat.jpeg"])
        let photo = material?.images.first.flatMap { UIImage(data: $0.jpeg) }
        #expect(photo.map { max($0.size.width * $0.scale, $0.size.height * $0.scale) } ?? 0 <= VaultSkillsMaterialReader.photoSide)
        #expect(flow.ayla.lookedAtFiles == 2)
    }

    @Test func theBandTakesTheStrongestColour() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
            UIColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 1).setFill()
            context.fill(CGRect(x: 10, y: 10, width: 20, height: 20))
        }
        let color = VaultLogoLook.strongestColor(in: image)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        color?.getRed(&red, green: &green, blue: &blue, alpha: nil)
        #expect(red > 0.85 && green > 0.4 && green < 0.7 && blue < 0.25)
        let grey = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        #expect(VaultLogoLook.strongestColor(in: grey) == nil)
    }
}

struct VaultImageFrameTests {
    private let image = CGSize(width: 1000, height: 500)
    private let frame = CGSize(width: 200, height: 200)

    @Test func theImageAlwaysCoversTheFrame() {
        #expect(VaultImageFrame.displayed(image: image, frame: frame, zoom: 1) == CGSize(width: 400, height: 200))
        let crop = VaultImageFrame.crop(image: image, frame: frame, zoom: 1, offset: .zero)
        #expect(crop == CGRect(x: 250, y: 0, width: 500, height: 500))
    }

    @Test func movingNeverShowsAnEdge() {
        #expect(VaultImageFrame.clamped(CGSize(width: 500, height: 40), image: image, frame: frame, zoom: 1) == CGSize(width: 100, height: 0))
        let left = VaultImageFrame.crop(image: image, frame: frame, zoom: 1, offset: CGSize(width: 100, height: 0))
        #expect(left.minX == 0)
    }

    @Test func zoomingTakesASmallerPart() {
        let crop = VaultImageFrame.crop(image: image, frame: frame, zoom: 2, offset: .zero)
        #expect(crop == CGRect(x: 375, y: 125, width: 250, height: 250))
    }
}
