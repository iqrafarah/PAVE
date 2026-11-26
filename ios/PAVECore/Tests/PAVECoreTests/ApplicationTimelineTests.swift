import Foundation
import Testing
@testable import PAVECore

@Suite struct ApplicationTimelineTests {
    let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func share(_ id: String, at date: Date, looks: [ShareLook] = [], revokedAt: Date? = nil) -> ProfileShare {
        ProfileShare(
            id: id, code: id, title: "Sollicitatie", recipientName: "Sanne de Vries", recipientOrganisation: "Jumbo", template: .employer,
            content: ShareContent(profile: ShareProfile(name: "Ravi")), expiresAt: date.addingTimeInterval(86_400 * 14),
            revokedAt: revokedAt, createdAt: date, looks: looks
        )
    }

    @Test func newestFirstWithSharesAndLooks() {
        var tracking = ApplicationTracking()
        tracking.set(.sent, at: now.addingTimeInterval(-3000))
        let shared = share("s1", at: now.addingTimeInterval(-2000), looks: [ShareLook(id: "l1", date: now.addingTimeInterval(-1000), action: .view, viewerName: "Sanne")])
        let events = ApplicationTimeline.events(tracking: tracking, shares: [shared], now: now)
        #expect(events.map(\.id) == ["look-l1", "shared-s1", "status-0"])
        #expect(events.first?.kind == .looked(by: "Sanne", downloaded: false))
    }

    @Test func aheadComesFirstSoonestOnTop() {
        var tracking = ApplicationTracking(deadline: now.addingTimeInterval(5 * 86_400))
        tracking.set(.concept, at: now.addingTimeInterval(-100))
        let events = ApplicationTimeline.events(tracking: tracking, shares: [], now: now)
        #expect(events.first?.kind == .deadline)
        #expect(events.first?.isAhead == true)
    }

    @Test func aPassedDeadlineOrSentApplicationShowsNoDeadline() {
        let passed = ApplicationTracking(deadline: now.addingTimeInterval(-86_400))
        #expect(!ApplicationTimeline.events(tracking: passed, shares: [], now: now).contains { $0.kind == .deadline })
        var sent = ApplicationTracking(deadline: now.addingTimeInterval(86_400))
        sent.set(.sent, at: now)
        #expect(!ApplicationTimeline.events(tracking: sent, shares: [], now: now).contains { $0.kind == .deadline })
    }

    @Test func theInvitationShowsOnlyOnceItArrived() {
        var tracking = ApplicationTracking()
        tracking.invitation = ApplicationInvitation(arrivesAt: now.addingTimeInterval(60), slots: [now.addingTimeInterval(86_400)])
        #expect(ApplicationTimeline.events(tracking: tracking, shares: [], now: now).isEmpty)
        tracking.invitation?.arrivesAt = now.addingTimeInterval(-60)
        tracking.invitation?.chosen = now.addingTimeInterval(86_400)
        let events = ApplicationTimeline.events(tracking: tracking, shares: [], now: now)
        #expect(events.map(\.kind) == [.talk, .invited])
        #expect(events.first?.isAhead == true)
    }

    @Test func stoppingAShareIsAMoment() {
        let stopped = share("s2", at: now.addingTimeInterval(-500), revokedAt: now.addingTimeInterval(-100))
        let events = ApplicationTimeline.events(tracking: ApplicationTracking(), shares: [stopped], now: now)
        #expect(events.first?.kind == .stoppedSharing(recipient: stopped.recipient))
    }
}
