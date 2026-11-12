import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct VaultAddEvidenceTests {
    /// Records what the flow sends and fails where a test asks it to.
    private actor FakeVault: VaultService {
        var added: [VaultItemDraft] = []
        var attached: [VaultFileRole] = []
        var skills: [[String]] = []
        var aylaAllowed: [String] = []
        var categoryFolders: [VaultCategoryFolder] = []
        var failSkillsOnce = false
        var coverColumnExists = true
        var categoryTableExists = true

        func failNextSkills() { failSkillsOnce = true }
        func dropCoverColumn() { coverColumnExists = false }
        func dropCategoryTable() { categoryTableExists = false }

        func contents() async throws -> VaultContents { VaultContents() }

        func add(_ draft: VaultItemDraft) async throws -> String {
            added.append(draft)
            return "item-\(added.count)"
        }

        func attach(_ upload: VaultUpload, to itemID: String) async throws {
            if upload.role == .cover, !coverColumnExists { throw VaultError.missingColumn }
            attached.append(upload.role)
        }

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

        func categoryFolders() async throws -> [VaultCategoryFolder] {
            guard categoryTableExists else { throw VaultError.missingColumn }
            return categoryFolders
        }

        func saveCategoryFolder(_ folder: VaultCategoryFolder) async throws {
            guard categoryTableExists else { throw VaultError.missingColumn }
            categoryFolders.removeAll { $0.category == folder.category }
            categoryFolders.append(folder)
        }

        func update(_ draft: VaultItemDraft, itemID: String) async throws {}
        func move(itemID: String, to folderID: String?) async throws {}
        func delete(_ item: VaultItem) async throws {}
        func createFolder(named name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> (folder: VaultFolder, styleSaved: Bool) {
            throw VaultError.unavailable
        }
        func updateFolder(id: String, name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> Bool { true }
        func deleteFolder(id: String) async throws {}
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

    @Test func aFileGivesTheTitleAFirstGuess() async {
        let flow = VaultAddEvidenceModel(vault: VaultModel(service: FakeVault()), category: .projects, folderID: nil)
        flow.pick(.success(pdf))
        #expect(flow.draft.title == "LiveWall eindstage verslag")
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

    @Test func categoryFoldersCanBeChangedAndHidden() async {
        let model = VaultModel(service: FakeVault())
        await model.load()
        #expect(await model.updateCategory(.projects, name: "Mijn werk", color: .blue, icon: .codeBracket))
        #expect(model.title(of: .projects) == "Mijn werk")
        #expect(model.style(of: .projects).color == .blue)
        await model.hide(.feedback)
        #expect(model.isHidden(.feedback))
        await model.showHiddenCategories()
        #expect(!model.hasHiddenCategories)
    }

    @Test func categoryFoldersStayOnThePhoneUntilTheTableExists() async {
        let service = FakeVault()
        await service.dropCategoryTable()
        let model = VaultModel(service: service)
        await model.hide(.diplomas)
        #expect(model.isHidden(.diplomas))
        defer { UserDefaults.standard.removeObject(forKey: "vaultCategoryFolders") }
        let reopened = VaultModel(service: service)
        await reopened.load()
        #expect(reopened.isHidden(.diplomas))
    }
}
