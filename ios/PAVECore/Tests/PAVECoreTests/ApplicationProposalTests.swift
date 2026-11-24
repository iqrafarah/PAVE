import Foundation
import Testing
@testable import PAVECore

@Suite("What goes on the CV for a vacancy")
struct ApplicationProposalTests {
    private let today = VaultDay(year: 2026, month: 11, day: 24)
    private let vacancy = Vacancy(
        id: "v", title: "Junior iOS-ontwikkelaar", company: "Appwerk", source: .adzuna,
        matches: [.init(skill: "Swift", requirement: "r")], skillGap: [.init(skill: "Scrum", requirement: "r")]
    )

    private func item(_ id: String, _ category: VaultCategory, skills: [String] = [], end: VaultDay? = nil, current: Bool = false) -> VaultItem {
        VaultItem(id: id, category: category, title: "Titel \(id)", description: "Wat ik deed.", startDate: VaultDay(year: 2020, month: 1, day: 1), endDate: end, isCurrent: current, skills: skills)
    }

    private var items: [VaultItem] {
        [
            item("fits", .internships, skills: ["Swift"], end: VaultDay(year: 2021, month: 6, day: 1)),
            item("now", .workExperience, current: true),
            item("recent", .workExperience, end: VaultDay(year: 2025, month: 6, day: 1)),
            item("old", .internships, end: VaultDay(year: 2021, month: 8, day: 1)),
            item("diploma", .diplomas, end: VaultDay(year: 2018, month: 7, day: 1)),
            item("project", .projects, end: VaultDay(year: 2025, month: 1, day: 1)),
        ]
    }

    private func draft() -> ApplicationDraft { ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf") }

    private func id(_ source: String, in draft: ApplicationDraft) -> String {
        draft.cv.sections.flatMap(\.entries).first { $0.sourceItemID == source }!.id
    }

    @Test("What fits, is going on or is recent is on; old and unrelated is off; a diploma always stays")
    func choicesHaveAReason() {
        let draft = draft()
        let choices = ApplicationProposal.choices(for: draft, items: items, today: today)
        #expect(choices[id("fits", in: draft)] == .init(isOn: true, reason: .fits(["Swift"])))
        #expect(choices[id("now", in: draft)] == .init(isOn: true, reason: .current))
        #expect(choices[id("recent", in: draft)] == .init(isOn: true, reason: .recent))
        #expect(choices[id("old", in: draft)] == .init(isOn: false, reason: .oldAndUnrelated))
        #expect(choices[id("diploma", in: draft)] == .init(isOn: true, reason: .education))
    }

    @Test("For one page the least fitting goes first, and as little as needed")
    func fitsOnOnePage() {
        let draft = draft()
        var asked = 0
        // A page holds four entries here.
        let result = ApplicationProposal.fitted(draft, items: items, today: today) { candidate in
            asked += 1
            return candidate.cv.sections.flatMap(\.entries).filter(\.isVisible).count > 4 ? 2 : 1
        }
        let on = Set(result.draft.cv.sections.flatMap(\.entries).filter(\.isVisible).compactMap(\.sourceItemID))
        #expect(on == ["fits", "now", "recent", "diploma"])
        #expect(result.choices[id("project", in: draft)] == .init(isOn: false, reason: .forOnePage))
        #expect(result.choices[id("old", in: draft)]?.reason == .oldAndUnrelated)
        #expect(asked <= 5)
    }

    @Test("What fits on a page is left as it is")
    func nothingIsTrimmedWhenItFits() {
        let draft = draft()
        let result = ApplicationProposal.fitted(draft, items: items, today: today) { _ in 1 }
        #expect(result.choices.values.filter { $0.reason == .forOnePage }.isEmpty)
        #expect(result.draft.cv.sections.flatMap(\.entries).filter(\.isVisible).count == 5)
    }

    @Test("The strongest experience and the diplomas stay, however short the page")
    func somethingAlwaysStays() {
        let draft = draft()
        let result = ApplicationProposal.fitted(draft, items: items, today: today) { _ in 2 }
        let on = Set(result.draft.cv.sections.flatMap(\.entries).filter(\.isVisible).compactMap(\.sourceItemID))
        #expect(on == ["fits", "diploma"])
    }
}
