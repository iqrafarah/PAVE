import Foundation
import Testing
@testable import PAVECore

@Suite("What the vacancy asks for, set against the CV")
struct ApplicationCoverageTests {
    private let vacancy = Vacancy(
        id: "v", title: "Junior iOS-ontwikkelaar", company: "Appwerk", source: .adzuna,
        matches: [.init(skill: "Swift", requirement: "Kennis van Swift"), .init(skill: "Scrum", requirement: "Je werkt in sprints"), .init(skill: "Git", requirement: "Versiebeheer")],
        skillGap: [.init(skill: "CI/CD", requirement: "Ervaring met pipelines")]
    )

    private var items: [VaultItem] {
        [
            VaultItem(id: "a", category: .internships, title: "Stage", organisationName: "Pixelwerk", status: .verified, skills: ["swift"]),
            VaultItem(id: "b", category: .certificates, title: "PSM I", organisationName: "Scrum.org", skills: ["Scrum"]),
            VaultItem(id: "c", category: .diplomas, title: "HBO-ICT", status: .verified),
        ]
    }

    @Test("Shown by evidence on the CV, left off, only named, or not in the vault")
    func everyRequirementHasItsState() {
        var draft = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf")
        draft.cv.skills = ["Swift", "Scrum", "Git"]
        let certificate = draft.cv.sections.flatMap(\.entries).first { $0.sourceItemID == "b" }!
        ApplicationProposal.apply([certificate.id: false], to: &draft)
        let found = ApplicationCoverage.requirements(of: draft, items: items)
        #expect(found.map(\.skill) == ["Swift", "Scrum", "Git", "CI/CD"])
        #expect(found[0].state == .shown(["Stage"]))
        #expect(found[1].state == .available([certificate.id]))
        #expect(found[2].state == .named)
        #expect(found[3].state == .missing)
        #expect(found.filter(\.isCovered).count == 2)
        #expect(found[3].text == "Ervaring met pipelines")
    }

    @Test("The tick is for verified evidence that the entry still describes")
    func verifiedOnlyWhileTheEntrySaysWhatWasVerified() {
        var draft = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf")
        ApplicationVerification.mark(&draft, items: items)
        func entry(_ source: String) -> CVEntry { draft.cv.sections.flatMap(\.entries).first { $0.sourceItemID == source }! }
        #expect(entry("a").isVerified)
        #expect(!entry("b").isVerified)
        #expect(ApplicationVerification.showsTick(draft))
        // What was done there is the user's own; the title is what was verified.
        let section = draft.cv.sections.firstIndex { $0.kind == .experience }!
        draft.cv.sections[section].entries[0].description = "Bouwde een app."
        ApplicationVerification.mark(&draft, items: items)
        #expect(entry("a").isVerified)
        draft.cv.sections[section].entries[0].title = "Senior stage"
        ApplicationVerification.mark(&draft, items: items)
        #expect(!entry("a").isVerified)
        draft.showsVerified = false
        #expect(!ApplicationVerification.showsTick(draft))
    }

    @Test("A draft kept before the tick existed still opens, and the tick is never read from the file")
    func olderDraftsOpen() throws {
        var draft = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf")
        ApplicationVerification.mark(&draft, items: items)
        let back = try JSONDecoder().decode(ApplicationDraft.self, from: JSONEncoder().encode(draft))
        #expect(back.cv.sections.flatMap(\.entries).allSatisfy { !$0.isVerified })
        #expect(back.marksVerified)
    }
}
