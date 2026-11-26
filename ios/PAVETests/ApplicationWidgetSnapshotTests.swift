import Foundation
import Testing
@testable import PAVE
import PAVECore

@MainActor
struct ApplicationWidgetSnapshotTests {
    private func draft(_ id: String, company: String, status: ApplicationStatus, deadline: Date?) -> ApplicationDraft {
        var draft = ApplicationBuilder.draft(for: Vacancy(id: id, title: "Developer", company: company, source: .example), items: [], name: "Ravi")
        var tracking = ApplicationTracking(status: status, deadline: deadline)
        tracking.changedAt = .now
        draft.tracking = tracking
        return draft
    }

    @Test func openApplicationsWithTheNearestDeadlineFirst() {
        let now = Date.now
        let drafts = [
            draft("a", company: "Later", status: .concept, deadline: now.addingTimeInterval(10 * 86_400)),
            draft("b", company: "Soon", status: .concept, deadline: now.addingTimeInterval(2 * 86_400)),
            draft("c", company: "Sent", status: .sent, deadline: now.addingTimeInterval(86_400)),
            draft("d", company: "Done", status: .rejected, deadline: nil),
        ]
        let share = ProfileShare(
            id: "s", code: String(repeating: "a", count: 32), title: "Sollicitatie", recipientName: "Sanne", template: .employer,
            content: ShareContent(profile: ShareProfile(name: "Ravi"), vacancyID: "b"), expiresAt: now.addingTimeInterval(86_400),
            looks: [ShareLook(id: "l", date: now, action: .view)]
        )
        let snapshot = ApplicationWidgetSnapshot.snapshot(drafts: drafts, shares: [share], now: now)
        #expect(snapshot.rows.map(\.company) == ["Soon", "Later", "Sent"])
        #expect(snapshot.rows[0].looks == 1)
        #expect(snapshot.rows[2].deadlineDays == nil)
    }
}
