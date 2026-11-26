import Foundation
import Testing
@testable import PAVECore

struct PracticeReportTests {
    @Test func theRequestHoldsOnlyWhatAylaMaySee() throws {
        var allowed = VaultItem(id: "a", category: .projects, title: "PAVE iOS-app")
        allowed.aylaAllowedAt = .now
        let hidden = VaultItem(id: "b", category: .projects, title: "Geheim")
        let request = PracticeReportRequest(vacancy: Vacancy(id: "v", title: "iOS developer", company: "Appwerk", source: .example), turns: [(false, "Vertel eens over jezelf."), (true, "Ik bouw apps in Swift.")], items: [allowed, hidden])
        #expect(request.evidence == ["PAVE iOS-app"])
        #expect(request.turns.map(\.role) == ["ayla", "user"])
    }

    @Test func aReportFromTheServerReadsWithoutADateAndKeepsOneWhenSaved() throws {
        let report = try JSONDecoder().decode(PracticeReport.self, from: Data(#"{"verdict":"Goed begin.","strengths":["Je noemde je app."],"improve":[],"examples":[{"question":"Waarom wij?","answer":"Omdat …"}]}"#.utf8))
        #expect(report.verdict == "Goed begin.")
        #expect(report.examples.count == 1)
        let kept = try JSONDecoder().decode(PracticeReport.self, from: JSONEncoder().encode(report))
        #expect(abs(kept.madeAt.timeIntervalSince(report.madeAt)) < 0.01)
    }
}
