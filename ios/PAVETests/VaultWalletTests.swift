import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct VaultWalletTests {
    /// A demo wallet with a diploma and a badge, of which the badge is already in the vault, and a vault with the
    /// example folder Diploma's.
    private actor FakeVault: VaultService {
        var imported: [[String]] = []
        var moved: [String: [String]] = [:]
        var fails = false
        var notDeployed = false
        var stored = VaultContents(folders: [VaultFolder(id: "folder-diplomas", name: "Diploma's", color: .green, icon: .academicCap)])

        let credentials = [
            VaultWalletCredential(id: "diploma-propedeuse", category: .diplomas, format: "Diploma", title: "Propedeuse HBO-ICT", issuer: "Hogeschool Kempenland"),
            VaultWalletCredential(id: "badge-teamwork", category: .badges, format: "Open Badge", title: "Samenwerken in een projectteam", issuer: "Hogeschool Kempenland", imported: true),
        ]

        func failImport() { fails = true }
        func undeploy() { notDeployed = true }

        func walletCredentials() async throws -> [VaultWalletCredential] {
            if notDeployed { throw VaultError.notSetUp }
            return credentials
        }

        func importFromWallet(_ credentialIDs: [String]) async throws -> [String] {
            if fails { throw VaultError.noConnection }
            imported.append(credentialIDs)
            stored.items.append(VaultItem(id: "item-1", category: .diplomas, title: "Propedeuse HBO-ICT", status: .verified, source: .import))
            return ["item-1"]
        }

        func contents() async throws -> VaultContents { stored }
        func setFolders(_ folderIDs: [String], itemID: String) async throws { moved[itemID] = folderIDs }
        func add(_ draft: VaultItemDraft) async throws -> String { "" }
        func attach(_ upload: VaultUpload, to itemID: String) async throws {}
        func fileData(_ file: VaultItem.File) async throws -> Data { Data() }
        func addSkills(_ names: [String], to itemID: String) async throws {}
        func setAylaAllowed(_ allowed: Bool, itemID: String) async throws {}
        func update(_ draft: VaultItemDraft, itemID: String) async throws {}
        func delete(_ item: VaultItem) async throws {}
        func createFolder(named name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> (folder: VaultFolder, styleSaved: Bool) {
            (VaultFolder(id: name, name: name, color: color, icon: icon), true)
        }
        func updateFolder(id: String, name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> Bool { true }
        func deleteFolder(id: String) async throws {}
        func removeFile(_ file: VaultItem.File) async throws {}
        func removeSkills(_ names: [String], from itemID: String) async throws {}
        func suggestSkills(for draft: VaultItemDraft, material: VaultSkillsMaterial, existing: [String], known: [String]) async throws -> [VaultSkillSuggestion] { [] }
    }

    private func wallet(_ service: FakeVault, folderID: String? = nil) async -> VaultWalletModel {
        let vault = VaultModel(service: service)
        await vault.load()
        let wallet = VaultWalletModel(vault: vault, folderID: folderID)
        wallet.checkDuration = .zero
        await wallet.load()
        return wallet
    }

    @Test func whatIsAlreadyInTheVaultCannotBeChosenAgain() async {
        let wallet = await wallet(FakeVault())
        #expect(wallet.state == .ready)
        #expect(wallet.available.map(\.id) == ["diploma-propedeuse"])
        wallet.toggle(wallet.credentials[1])
        #expect(wallet.selected.isEmpty)
        wallet.toggle(wallet.credentials[0])
        #expect(wallet.selected == ["diploma-propedeuse"])
        wallet.toggle(wallet.credentials[0])
        #expect(wallet.selected.isEmpty)
    }

    @Test func chosenCredentialsAreCheckedAndGoIntoTheFolderOfTheirKindAndTheOneYouStartedFrom() async {
        let service = FakeVault()
        let wallet = await wallet(service, folderID: "folder-start")
        wallet.toggle(wallet.credentials[0])
        let count = await wallet.importSelected()
        #expect(count == 1)
        #expect(await service.imported == [["diploma-propedeuse"]])
        #expect(await service.moved["item-1"] == ["folder-start", "folder-diplomas"])
        #expect(wallet.checked["diploma-propedeuse"] == VaultWalletModel.Check.allCases.count)
        #expect(wallet.vault.items.first?.status == .verified)
        #expect(!wallet.isImporting)
    }

    @Test func aFailedImportSaysSoAndKeepsTheChoice() async {
        let service = FakeVault()
        await service.failImport()
        let wallet = await wallet(service)
        wallet.toggle(wallet.credentials[0])
        #expect(await wallet.importSelected() == nil)
        #expect(wallet.problem == VaultMessages.walletImportFailed)
        #expect(wallet.checked.isEmpty)
        #expect(wallet.selected == ["diploma-propedeuse"])
    }

    @Test func aWalletFunctionThatIsNotThereYetIsSaidPlainly() async {
        let service = FakeVault()
        await service.undeploy()
        let wallet = await wallet(service)
        #expect(wallet.state == .failed(VaultMessages.walletNotSetUp))
    }

    @Test func theSourceOfAnImportSaysItIsADemo() {
        #expect(VaultItem.Source.import.title == "Uit je wallet (demo)")
        #expect(VaultMessages.walletAdd(1) == "Zet 1 bewijsstuk in je kluis")
        #expect(VaultMessages.walletAdd(3) == "Zet 3 bewijsstukken in je kluis")
    }
}
