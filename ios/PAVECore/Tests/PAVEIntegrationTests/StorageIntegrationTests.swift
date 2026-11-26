import Foundation
import PAVECore
import Testing

/// Files in the private `pave-vault` bucket: upload, read back, remove, and closed to everyone else.
@Suite(.localSupabase)
struct StorageIntegrationTests {
    private func itemWithFile(for user: TestUser, bytes: Data) async throws -> (VaultItem, VaultItem.File) {
        var draft = VaultItemDraft(category: .certificates)
        draft.title = "Certificaat met bestand"
        let id = try await user.vault.add(draft)
        try await user.vault.attach(VaultUpload(data: bytes, fileName: "certificaat.txt", mimeType: "text/plain"), to: id)
        let item = try #require(try await user.vault.contents().items.first { $0.id == id })
        let file = try #require(item.files.first)
        return (item, file)
    }

    @Test func anUploadedFileComesBackTheSame() async throws {
        let user = try await TestUser.make("upload")
        let bytes = Data("PAVE integratietest \(UUID())".utf8)
        let (_, file) = try await itemWithFile(for: user, bytes: bytes)

        #expect(file.name == "certificaat.txt")
        #expect(file.storagePath.hasPrefix(try #require(await user.auth.accountID()).lowercased()))
        #expect(try await user.vault.fileData(file) == bytes)
    }

    @Test func aRemovedFileIsGone() async throws {
        let user = try await TestUser.make("remove")
        let (item, file) = try await itemWithFile(for: user, bytes: Data("weg".utf8))
        try await user.vault.removeFile(file)

        #expect(try await user.vault.contents().items.first { $0.id == item.id }?.files.isEmpty == true)
        await #expect(throws: (any Error).self) { try await user.vault.fileData(file) }
    }

    @Test func anotherAccountCannotDownloadYourFile() async throws {
        async let owner = TestUser.make("fileowner")
        async let stranger = TestUser.make("filestranger")
        let (a, b) = try await (owner, stranger)
        let (_, file) = try await itemWithFile(for: a, bytes: Data("privé".utf8))

        await #expect(throws: (any Error).self) { try await b.vault.fileData(file) }
    }

    @Test func aFileTypeTheBucketDoesNotAllowIsRefused() async throws {
        let user = try await TestUser.make("filetype")
        var draft = VaultItemDraft(category: .projects)
        draft.title = "Verkeerd bestand"
        let id = try await user.vault.add(draft)
        let upload = VaultUpload(data: Data([0x4d, 0x5a]), fileName: "programma.exe", mimeType: "application/x-msdownload")
        await #expect(throws: (any Error).self) { try await user.vault.attach(upload, to: id) }
    }
}
