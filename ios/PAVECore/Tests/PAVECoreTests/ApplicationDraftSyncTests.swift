import Foundation
import Testing
@testable import PAVECore

struct ApplicationDraftSyncTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func draft(_ id: String, at offset: TimeInterval) -> ApplicationDraft {
        ApplicationDraft(
            vacancy: Vacancy(id: id, title: "Junior IT-consultant", company: "Kade", source: .example), cv: CVContent(name: "Ravi"),
            letter: LetterContent(), updatedAt: base.addingTimeInterval(offset)
        )
    }

    private func remote(_ id: String, at offset: TimeInterval, deleted: Bool = false) -> RemoteApplicationDraft {
        let date = base.addingTimeInterval(offset)
        return RemoteApplicationDraft(id: id, updatedAt: date, deletedAt: deleted ? date : nil, draft: deleted ? nil : draft(id, at: offset))
    }

    @Test func aDraftFromAnotherDeviceComesIn() {
        let plan = ApplicationDraftSync.plan(local: [], deletedLocally: [:], remote: [remote("a", at: 0)])
        #expect(plan.download.map(\.id) == ["a"])
        #expect(plan.upload.isEmpty)
    }

    @Test func aDraftOnlyHereGoesUp() {
        let plan = ApplicationDraftSync.plan(local: [draft("a", at: 0)], deletedLocally: [:], remote: [])
        #expect(plan.upload.map(\.id) == ["a"])
    }

    @Test func theOneChangedLastWins() {
        let newerHere = ApplicationDraftSync.plan(local: [draft("a", at: 60)], deletedLocally: [:], remote: [remote("a", at: 0)])
        #expect(newerHere.upload.map(\.id) == ["a"])
        #expect(newerHere.download.isEmpty)
        let newerThere = ApplicationDraftSync.plan(local: [draft("a", at: 0)], deletedLocally: [:], remote: [remote("a", at: 60)])
        #expect(newerThere.download.map(\.id) == ["a"])
        #expect(newerThere.upload.isEmpty)
    }

    @Test func theSameCopyMovesNothing() {
        let plan = ApplicationDraftSync.plan(local: [draft("a", at: 0.3)], deletedLocally: [:], remote: [remote("a", at: 0)])
        #expect(plan.isEmpty)
    }

    @Test func deletedElsewhereIsRemovedHere() {
        let plan = ApplicationDraftSync.plan(local: [draft("a", at: 0)], deletedLocally: [:], remote: [remote("a", at: 60, deleted: true)])
        #expect(plan.removeLocally == ["a"])
    }

    @Test func changedHereAfterItWasDeletedElsewhereStays() {
        let plan = ApplicationDraftSync.plan(local: [draft("a", at: 120)], deletedLocally: [:], remote: [remote("a", at: 60, deleted: true)])
        #expect(plan.upload.map(\.id) == ["a"])
        #expect(plan.removeLocally.isEmpty)
    }

    @Test func deletedHereIsDeletedInTheAccount() {
        let plan = ApplicationDraftSync.plan(local: [], deletedLocally: ["a": base.addingTimeInterval(60)], remote: [remote("a", at: 0)])
        #expect(plan.deleteRemotely.keys.sorted() == ["a"])
        #expect(plan.download.isEmpty)
    }

    @Test func changedElsewhereAfterItWasDeletedHereComesBack() {
        let plan = ApplicationDraftSync.plan(local: [], deletedLocally: ["a": base], remote: [remote("a", at: 60)])
        #expect(plan.download.map(\.id) == ["a"])
        #expect(plan.settled == ["a"])
    }

    @Test func aDeletionTheAccountKnowsIsForgotten() {
        let plan = ApplicationDraftSync.plan(local: [], deletedLocally: ["a": base, "b": base], remote: [remote("a", at: 0, deleted: true)])
        #expect(plan.settled == ["a", "b"])
        #expect(plan.isEmpty)
    }

    @Test func rowsReadBackAsTheyWereWritten() throws {
        let original = draft("a", at: 0.25)
        let body = try SupabaseApplicationDraftService.row(id: "a", draft: original, updatedAt: original.updatedAt, deletedAt: nil)
        let rows = try SupabaseApplicationDraftService.decode(Data("[".utf8) + body + Data("]".utf8))
        #expect(rows.first?.draft == original)
        #expect(abs((rows.first?.updatedAt ?? .distantPast).timeIntervalSince(original.updatedAt)) < 0.01)
    }

    @Test func aDeletedRowHasNoDraft() throws {
        let body = try SupabaseApplicationDraftService.row(id: "a", draft: nil, updatedAt: base, deletedAt: base)
        let rows = try SupabaseApplicationDraftService.decode(Data("[".utf8) + body + Data("]".utf8))
        #expect(rows == [RemoteApplicationDraft(id: "a", updatedAt: base, deletedAt: base, draft: nil)])
    }
}
