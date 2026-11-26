import Foundation
import Testing
@testable import PAVECore

@Suite struct ShareFilesTests {
    private func item(_ id: String, status: VaultItem.Status, files: [VaultItem.File]) -> VaultItem {
        VaultItem(id: id, category: .diplomas, title: id, status: status, files: files)
    }

    private let document = VaultItem.File(id: "f", name: "Diploma.pdf", mimeType: "application/pdf", storagePath: "u/i/d.pdf")
    private let cover = VaultItem.File(id: "c", name: "cover.jpg", mimeType: "image/jpeg", storagePath: "u/i/c.jpg", role: .cover)

    @Test func everyDocumentGoesAlongExceptRejected() {
        let items = [
            item("verified", status: .verified, files: [document]),
            item("own", status: .toVerify, files: [document]),
            item("rejected", status: .rejected, files: [document]),
            item("coverOnly", status: .verified, files: [cover]),
            item("none", status: .verified, files: []),
        ]
        #expect(ShareFiles.byDefault(items) == ["verified", "own"])
    }

    @Test func aSelectionWithoutAChoiceFollowsTheDefault() {
        let items = [item("own", status: .toVerify, files: [document])]
        #expect(ShareFiles.of(SavedProfile(name: "x", template: .employer), items: items) == ["own"])
        #expect(ShareFiles.of(SavedProfile(name: "x", template: .employer, fileIDs: ["kept"]), items: items) == ["kept"])
    }
}

struct ShareFilesPerFileTests {
    private func item(_ id: String, files: [String]) -> VaultItem {
        VaultItem(id: id, category: .diplomas, title: "Diploma", files: files.map { VaultItem.File(id: $0, name: "\($0).pdf", mimeType: "application/pdf", storagePath: "x/\($0)") })
    }

    @Test func aFileTurnedOffStaysBehind() {
        let diploma = item("i1", files: ["f1", "f2"])
        #expect(ShareFiles.documents(of: diploma, hidden: ["f2"]).map(\.id) == ["f1"])
        #expect(ShareFiles.sharesDocument(diploma, hidden: ["f2"]))
        #expect(!ShareFiles.sharesDocument(diploma, hidden: ["f1", "f2"]))
    }

    @Test func onlyHiddenFilesOfSharedEvidenceAreKept() {
        let items = [item("i1", files: ["f1", "f2"]), item("i2", files: ["f3"])]
        #expect(ShareFiles.hidden(["f2", "f3", "gone"], in: items, withFiles: ["i1"]) == ["f2"])
    }
}
