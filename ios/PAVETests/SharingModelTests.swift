import Foundation
import Testing
@testable import PAVE
import PAVECore

@MainActor
struct SharingModelTests {
    final class FakeShares: ShareService, @unchecked Sendable {
        var stored: [ProfileShare] = []
        var uploads: [(kind: String, shareID: String, bytes: Int)] = []
        var calls: [String] = []
        var fails = false

        func shares() async throws -> [ProfileShare] {
            if fails { throw ShareError.unavailable }
            return stored
        }
        func create(_ draft: ShareDraft, now: Date) async throws -> ProfileShare {
            calls.append("create")
            let share = ProfileShare(
                id: "s\(stored.count + 1)", code: String(repeating: "d", count: 32), title: draft.title, recipientName: draft.recipientName,
                recipientOrganisation: draft.recipientOrganisation, purpose: draft.purpose, template: draft.template, itemIDs: draft.itemIDs,
                content: draft.content, allowsDownload: draft.allowsDownload, expiresAt: draft.duration.end(from: now), createdAt: now
            )
            stored.insert(share, at: 0)
            return share
        }
        func upload(pdf: Data, kind: String, shareID: String) async throws -> String {
            uploads.append((kind, shareID, pdf.count))
            return "user/\(shareID)/\(kind).pdf"
        }
        func setDocuments(_ documents: [String: String], of share: ProfileShare) async throws { calls.append("documents \(documents.keys.sorted())") }
        func setPaused(_ isPaused: Bool, shareID: String) async throws { calls.append("paused \(isPaused)") }
        func extend(shareID: String, until: Date) async throws { calls.append("extend") }
        func revoke(_ share: ProfileShare) async throws { calls.append("revoke") }
        func employer(slug: String) async throws -> FairEmployer { FairEmployer(slug: slug, name: "Kade", about: "Advies") }
    }

    private var application: ApplicationDraft {
        var draft = ApplicationBuilder.draft(for: Vacancy(id: "v", title: "Junior", company: "Kade", source: .adzuna), items: [], name: "Ravi")
        draft.cv.profile = "Ik bouw apps."
        return draft
    }

    @Test func sharingTheApplicationKeepsTheCVAndLetterAsPdfWithTheShare() async throws {
        let service = FakeShares()
        let model = SharingModel(service: service, webURL: URL(string: "https://pave.example.nl"))
        let app = application
        let draft = ShareDraft(
            title: "Sollicitatie Junior", recipientName: "Sanne", recipientOrganisation: "Kade", template: .employer,
            content: ShareContent(profile: ShareProfile(name: "Ravi"), cv: app.cv, letter: app.letter, vacancyID: "v")
        )
        let share = try #require(await model.create(draft, application: app, photo: nil))
        #expect(service.uploads.map(\.kind) == ["cv", "letter"])
        #expect(service.uploads.allSatisfy { $0.bytes > 1000 })
        #expect(share.content.documents == ["cv": "user/s1/cv.pdf", "letter": "user/s1/letter.pdf"])
        #expect(service.calls.contains("documents [\"cv\", \"letter\"]"))
        #expect(model.live.map(\.id) == ["s1"])
        #expect(model.link(for: share)?.absoluteString == "https://pave.example.nl/gedeeld/" + String(repeating: "d", count: 32))
    }

    @Test func nothingIsSharedWithoutARecipient() async {
        let service = FakeShares()
        let model = SharingModel(service: service, webURL: nil)
        let draft = ShareDraft(title: "x", template: .employer, itemIDs: ["i"], content: ShareContent(profile: ShareProfile(name: "Ravi")))
        #expect(await model.create(draft, application: nil, photo: nil) == nil)
        #expect(service.calls.isEmpty)
    }

    @Test func pausingExtendingAndTakingBackChangeTheShareHere() async throws {
        let service = FakeShares()
        let model = SharingModel(service: service, webURL: nil)
        let draft = ShareDraft(title: "Beurs", recipientName: "Bezoekers", template: .fair, itemIDs: ["i"], content: ShareContent(profile: ShareProfile(name: "Ravi")))
        var share = try #require(await model.create(draft, application: nil, photo: nil))
        await model.setPaused(true, share)
        #expect(model.share(share.id)?.state() == .paused)
        share = try #require(model.share(share.id))
        let before = share.expiresAt
        await model.extend(share, by: .week)
        #expect(model.share(share.id)?.expiresAt == before.addingTimeInterval(7 * 86_400))
        await model.revoke(try #require(model.share(share.id)))
        let revoked = try #require(model.share(share.id))
        #expect(revoked.state() == .revoked)
        #expect(revoked.itemIDs.isEmpty)
        #expect(model.live.isEmpty)
        #expect(model.ended.map(\.id) == [share.id])
        #expect(service.calls.suffix(3) == ["paused true", "extend", "revoke"])
    }

    @Test func withoutAnAccountThereIsNothingToShare() async {
        let model = SharingModel(service: nil, webURL: nil)
        await model.load()
        #expect(model.state == .unavailable)
    }

    @Test func anApplicationShowsWhatWasSharedForIt() async throws {
        let service = FakeShares()
        let model = SharingModel(service: service, webURL: nil)
        let profile = ShareProfile(name: "Ravi")
        let first = ShareDraft(title: "Sollicitatie", recipientName: "Sanne", template: .employer, content: ShareContent(profile: profile, cv: application.cv, vacancyID: "v"))
        let other = ShareDraft(title: "Beurs", recipientName: "Stand 4", template: .fair, itemIDs: ["x"], content: ShareContent(profile: profile))
        _ = await model.create(first, application: application, photo: nil)
        _ = await model.create(other, application: nil, photo: nil)
        await model.load()
        #expect(model.shares(forVacancy: "v").map(\.title) == ["Sollicitatie"])
        #expect(model.shares(forVacancy: "w").isEmpty)
    }
}
