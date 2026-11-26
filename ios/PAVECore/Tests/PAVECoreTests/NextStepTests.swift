import Foundation
import Testing
@testable import PAVECore

@Suite struct NextStepTests {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func draft(_ company: String, deadline: Date? = nil, talk: Date? = nil, status: ApplicationStatus = .concept) -> ApplicationDraft {
        var draft = ApplicationBuilder.draft(for: Vacancy(id: company, title: "Baan", company: company, source: .own), items: [], name: "Ravi")
        var tracking = ApplicationTracking(status: status, deadline: deadline)
        if let talk {
            tracking.invitation = ApplicationInvitation(arrivesAt: now.addingTimeInterval(-60), slots: [talk], chosen: talk)
        }
        draft.tracking = tracking
        return draft
    }

    private func fair(_ slug: String, at date: Date, answer: FairApplication.Answer? = nil) -> FairApplication {
        FairApplication(id: slug, employerSlug: slug, vacancyID: "v", vacancyTitle: "Bijbaan", card: FairApplicationCard(name: "Ravi"), status: .invited, invitedFor: date, answer: answer)
    }

    @Test func theSoonestOfTalksAndDeadlines() {
        let step = NextStep.pick(
            drafts: [draft("Kade", deadline: now.addingTimeInterval(5 * 86_400)), draft("Hetzner", talk: now.addingTimeInterval(86_400), status: .interview)],
            fair: [], employerName: { $0 }, now: now
        )
        #expect(step == NextStep(kind: .talk, company: "Hetzner", date: now.addingTimeInterval(86_400)))
    }

    @Test func anInvitationToAnswerGoesFirst() {
        let step = NextStep.pick(
            drafts: [draft("Kade", deadline: now.addingTimeInterval(3600))],
            fair: [fair("jumbo", at: now.addingTimeInterval(3 * 86_400))], employerName: { _ in "Jumbo" }, now: now
        )
        #expect(step?.kind == .answer)
        #expect(step?.company == "Jumbo")
    }

    @Test func pastAndSentLeaveNothing() {
        let step = NextStep.pick(
            drafts: [draft("Kade", deadline: now.addingTimeInterval(-60)), draft("Sioux", deadline: now.addingTimeInterval(86_400), status: .sent)],
            fair: [fair("ogd", at: now.addingTimeInterval(-60), answer: .accepted)], employerName: { $0 }, now: now
        )
        #expect(step == nil)
    }

    @Test func anAcceptedFairTalkCounts() {
        let step = NextStep.pick(drafts: [], fair: [fair("jumbo", at: now.addingTimeInterval(7200), answer: .accepted)], employerName: { _ in "Jumbo" }, now: now)
        #expect(step == NextStep(kind: .talk, company: "Jumbo", date: now.addingTimeInterval(7200)))
    }
}
