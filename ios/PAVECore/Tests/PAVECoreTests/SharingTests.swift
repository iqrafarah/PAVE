import Foundation
import Testing
@testable import PAVECore

@Suite("Sharing a profile")
struct SharingTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func share(_ id: String = "s", expires days: Double = 7, paused: Bool = false, revoked: Bool = false, vacancyID: String? = nil, looks: [ShareLook] = []) -> ProfileShare {
        ProfileShare(
            id: id, code: String(repeating: "a", count: 32), title: "Sollicitatie", recipientName: "Sanne", recipientOrganisation: "Kade",
            template: .employer, itemIDs: ["i"], content: ShareContent(profile: ShareProfile(name: "Ravi"), vacancyID: vacancyID),
            expiresAt: now.addingTimeInterval(days * 86_400), pausedAt: paused ? now : nil, revokedAt: revoked ? now : nil, createdAt: now, looks: looks
        )
    }

    @Test("Taken back wins, then ended, then paused, as share-view decides")
    func state() {
        #expect(share().state(at: now) == .active)
        #expect(share(paused: true).state(at: now) == .paused)
        #expect(share(expires: -1, paused: true).state(at: now) == .expired)
        #expect(share(expires: -1, paused: true, revoked: true).state(at: now) == .revoked)
        #expect(share().recipient == "Sanne (Kade)")
    }

    @Test("A share needs a recipient, a title and something in it")
    func draftProblems() {
        let empty = ShareContent(profile: ShareProfile(name: "Ravi"))
        #expect(ShareDraft(template: .employer, content: empty).problem == .noRecipient)
        #expect(ShareDraft(recipientName: "Sanne", template: .employer, content: empty).problem == .noTitle)
        #expect(ShareDraft(title: "x", recipientName: "Sanne", template: .employer, content: empty).problem == .nothingChosen)
        #expect(ShareDraft(title: "x", recipientName: "Sanne", template: .employer, itemIDs: ["i"], content: empty).problem == nil)
        #expect(ShareDraft(template: .fair, content: empty).duration == .week)
        #expect(ShareDuration.twoWeeks.end(from: now) == now.addingTimeInterval(14 * 86_400))
    }

    @Test("A scanned code is a share, an employer, or not PAVE's")
    func scanned() {
        let base = URL(string: "https://pave.example.nl")!
        let link = ShareLinks.share(String(repeating: "b", count: 32), base: base)
        #expect(link.absoluteString == "https://pave.example.nl/gedeeld/" + String(repeating: "b", count: 32))
        #expect(ShareLinks.scanned(link.absoluteString) == .share(code: String(repeating: "b", count: 32)))
        #expect(ShareLinks.scanned("https://localhost:3000/werkgever/kade-consultancy") == .employer(slug: "kade-consultancy"))
        #expect(ShareLinks.scanned("https://pave.example.nl/gedeeld/te-kort") == nil)
        #expect(ShareLinks.scanned("javascript:alert(1)") == nil)
        #expect(ShareLinks.scanned("Gewoon tekst") == nil)
    }

    @Test("PAVE proposes taking a share back when its application is over, or it ends soon")
    func suggestions() {
        func application(_ id: String, _ tracking: ApplicationTracking) -> ApplicationDraft {
            var draft = ApplicationBuilder.draft(for: Vacancy(id: id, title: "Dev", company: "Kade", source: .adzuna), items: [], name: "Ravi")
            draft.tracking = tracking
            return draft
        }
        let shares = [
            share("rejected", vacancyID: "v1"),
            share("late", vacancyID: "v2"),
            share("soon", expires: 0.5),
            share("fine", vacancyID: "v3"),
            share("gone", expires: -1, vacancyID: "v1"),
        ]
        let applications = [
            application("v1", ApplicationTracking(status: .rejected)),
            application("v2", ApplicationTracking(deadline: now.addingTimeInterval(-3 * 86_400))),
            application("v3", ApplicationTracking(status: .sent)),
        ]
        let found = ShareAdvice.suggestions(shares: shares, applications: applications, now: now)
        #expect(found.map(\.shareID) == ["rejected", "late", "soon"])
        #expect(found[0].reason == .applicationEnded(.rejected))
        #expect(found[1].reason == .deadlinePassed)
        #expect(found[2].reason == .endsSoon)
    }

    @Test("The report counts the last 30 days, the most looked-at share first")
    func report() {
        let looks = [
            ShareLook(id: "1", date: now.addingTimeInterval(-3600), action: .view),
            ShareLook(id: "2", date: now.addingTimeInterval(-7200), action: .download),
            ShareLook(id: "3", date: now.addingTimeInterval(-40 * 86_400), action: .view),
        ]
        let report = ShareAdvice.report([share("a", looks: looks), share("b", paused: true, looks: [looks[0]]), share("c", revoked: true)], now: now)
        #expect(report.active == 1)
        #expect(report.paused == 1)
        #expect(report.looks == 2)
        #expect(report.downloads == 1)
        #expect(report.byShare.map(\.shareID) == ["a", "b"])
        #expect(ShareAdvice.newLooks(in: [share("a", looks: looks)], since: now.addingTimeInterval(-5000)).map(\.look.id) == ["1"])
    }

    @Test("A share reads from the database, also after it was taken back and its content wiped")
    func decoding() throws {
        let json = """
        [{"id":"s1","code":"\(String(repeating: "c", count: 32))","title":"Beurs","recipient_name":"Bezoekers","recipient_organisation":null,
          "purpose":null,"template":"fair","item_ids":[],"content":{},"allows_download":false,
          "expires_at":"2026-12-02T10:00:00+00:00","paused_at":null,"revoked_at":"2026-11-25T10:00:00.123+00:00",
          "created_at":"2026-11-25T09:00:00.5+00:00",
          "profile_share_views":[{"id":"v1","viewed_at":"2026-11-25T09:30:00+00:00","action":"download","viewer_name":"Sanne","viewer_organisation":null}]}]
        """
        let rows = try SupabaseShareService.decoder.decode([SupabaseShareService.ShareRow].self, from: Data(json.utf8))
        let share = try #require(rows.first?.share)
        #expect(share.template == .fair)
        #expect(share.content.profile.name == "")
        #expect(share.state() == .revoked)
        #expect(share.looks.first?.action == .download)
        #expect(share.looks.first?.viewerName == "Sanne")
    }

    @Test("An employer reads with its vacancies, leaving out one that does not read")
    func employer() throws {
        let json = """
        [{"slug":"kade","name":"Kade","city":"Eindhoven","about":"Advies","stand":"Stand 12","website":null,"is_example":true,
          "vacancies":[{"id":"x","title":"Junior","company":"Kade","source":"example","matches":[],"skillGap":[]},{"kapot":true}]}]
        """
        let employer = try #require(try JSONDecoder().decode([FairEmployer].self, from: Data(json.utf8)).first)
        #expect(employer.vacancies.map(\.id) == ["x"])
        #expect(employer.isExample)
    }
}

@Suite("Asking Ayla to share")
struct AylaShareCommandTests {
    @Test("Sharing, stopping and asking who can see, said in ordinary words")
    func commands() {
        #expect(AylaShareCommand.command(in: "Deel mijn cv met Kade Consultancy voor twee weken") == .share(organisation: "Kade Consultancy", duration: .twoWeeks, withApplication: true))
        #expect(AylaShareCommand.command(in: "Ayla, deel mijn profiel met lumen data") == .share(organisation: "Lumen Data", duration: nil, withApplication: false))
        #expect(AylaShareCommand.command(in: "deel mijn cv en brief met Hetzner voor een maand") == .share(organisation: "Hetzner", duration: .month, withApplication: true))
        #expect(AylaShareCommand.command(in: "Stop met delen met Kade") == .stop(organisation: "Kade"))
        #expect(AylaShareCommand.command(in: "trek mijn gegevens bij kade in") == .stop(organisation: "Kade"))
        #expect(AylaShareCommand.command(in: "Wie kan mijn gegevens zien?") == .showShares)
        #expect(AylaShareCommand.command(in: "Wat is delen eigenlijk?") == nil)
        #expect(AylaShareCommand.command(in: "Hoe deel ik mijn cv het best met een werkgever?") == nil)
    }
}
