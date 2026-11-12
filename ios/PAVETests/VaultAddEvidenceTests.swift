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
        func suggestSkills(for draft: VaultItemDraft, existing: [String]) async throws -> [VaultSkillSuggestion] {
            [VaultSkillSuggestion(name: "Presenteren", reason: "Je gaf een eindpresentatie")]
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
    }

    private let pdf = VaultUpload(data: Data([1, 2, 3]), fileName: "LiveWall-eindstage-verslag.pdf", mimeType: "application/pdf")
    private let photo = VaultUpload(data: Data([1]), fileName: "Foto.jpeg", mimeType: "image/jpeg", role: .cover)

    private func filledFlow(_ service: FakeVault) async -> VaultAddEvidenceModel {
        let flow = VaultAddEvidenceModel(vault: VaultModel(service: service), category: .internships, folderID: nil)
        flow.pick(.success(pdf))
        flow.draft.organisationName = "LiveWall"
        flow.draft.startDate = VaultDay(year: 2025, month: 2, day: 1)
        flow.draft.description = "Front-end voor campagnes"
        await flow.next()
        return flow
    }

    @Test func aFileGivesTheTitleAFirstGuess() async {
        let flow = VaultAddEvidenceModel(vault: VaultModel(service: FakeVault()), category: .projects, folderID: nil)
        flow.pick(.success(pdf))
        #expect(flow.draft.title == "LiveWall eindstage verslag")
        #expect(flow.page == .details)
        flow.pick(.success(pdf))
        #expect(flow.documents.count == 1)
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
        await ayla.ask(for: VaultItemDraft(category: .projects), existing: [])
        #expect(ayla.state == .loaded([VaultSkillSuggestion(name: "Presenteren", reason: "Je gaf een eindpresentatie")]))
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
