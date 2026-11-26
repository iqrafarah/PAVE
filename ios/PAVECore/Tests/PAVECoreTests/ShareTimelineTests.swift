import Foundation
import Testing
@testable import PAVECore

struct ShareTimelineTests {
    private func share(_ id: String, looks: [ShareLook]) -> ProfileShare {
        ProfileShare(
            id: id, code: id, title: "Sollicitatie", recipientName: "Sanne de Vries", recipientOrganisation: "Kade",
            template: .employer, itemIDs: [], content: ShareContent(profile: ShareProfile(name: "Ravi")),
            expiresAt: .now.addingTimeInterval(86_400), looks: looks
        )
    }

    @Test func looksOfAllSharesComeNewestFirstPerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        let a = share("a", looks: [ShareLook(id: "1", date: morning, action: .view), ShareLook(id: "2", date: morning.addingTimeInterval(3600), action: .download)])
        let b = share("b", looks: [ShareLook(id: "3", date: morning.addingTimeInterval(-86_400 * 2), action: .view, viewerName: "Jan", viewerOrganisation: "Jumbo")])
        let days = ShareTimeline.days([a, b], calendar: calendar)
        #expect(days.count == 2)
        #expect(days[0].entries.map(\.look.id) == ["2", "1"])
        #expect(days[1].entries.first?.who == "Jan, Jumbo")
        #expect(days[1].entries.first?.namedThemselves == true)
        #expect(ShareTimeline.Entry(look: ShareLook(id: "x", date: morning, action: .view, viewerName: "sanne de vries"), share: a).namedThemselves == false)
        #expect(days[0].entries.first?.who == "Sanne de Vries (Kade)")
    }

    @Test func onlyLooksSinceAMomentWhenAsked() {
        let now = Date.now
        let s = share("a", looks: [ShareLook(id: "old", date: now.addingTimeInterval(-40 * 86_400), action: .view), ShareLook(id: "new", date: now, action: .view)])
        #expect(ShareTimeline.entries([s], since: now.addingTimeInterval(-30 * 86_400)).map(\.look.id) == ["new"])
    }
}
