import Foundation
import Testing
@testable import PAVECore

struct ApplicationBuilderTests {
    private let vacancy = Vacancy(
        id: "v", title: "Junior iOS-ontwikkelaar", company: "Appwerk", source: .adzuna,
        matches: [.init(skill: "Swift", requirement: "r")], skillGap: [.init(skill: "CI/CD", requirement: "r")]
    )

    private func item(_ id: String, _ category: VaultCategory, _ title: String, skills: [String] = [], end: VaultDay? = nil, status: VaultItem.Status = .verified) -> VaultItem {
        VaultItem(id: id, category: category, title: title, organisationName: "Org \(id)", endDate: end, status: status, skills: skills)
    }

    @Test func evidenceThatFitsTheVacancyComesFirst() {
        let items = [
            item("a", .workExperience, "Teamleider avondploeg", skills: ["Plannen"], end: VaultDay(year: 2025, month: 6, day: 1)),
            item("b", .internships, "Eindstage front-end", skills: ["Swift"], end: VaultDay(year: 2024, month: 1, day: 1)),
            item("c", .diplomas, "HBO-ICT", end: VaultDay(year: 2026, month: 7, day: 1)),
        ]
        let draft = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf")
        let experience = draft.cv.sections.first { $0.kind == .experience }
        #expect(experience?.entries.map(\.sourceItemID) == ["b", "a"])
        #expect(draft.cv.skills.first == "Swift")
        #expect(draft.cv.headline == "Student HBO-ICT")
        #expect(draft.cv.visibleSections.map(\.kind) == [.experience, .education])
    }

    @Test func rejectedAndArchivedEvidenceStaysOff() {
        var archived = item("x", .projects, "Oud project")
        archived.archivedAt = .now
        let items = [item("r", .certificates, "Afgewezen", status: .rejected), archived]
        let draft = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf")
        #expect(draft.cv.visibleSections.isEmpty)
    }

    @Test func theLetterOnlySaysWhatTheVaultSays() {
        let items = [item("b", .internships, "Eindstage front-end", skills: ["Swift", "SwiftUI"])]
        let letter = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf").letter
        #expect(letter.salutation == "Beste team van Appwerk,")
        #expect(letter.paragraphs.count == 3)
        #expect(letter.paragraphs[1].sourceItemIDs == ["b"])
        #expect(letter.paragraphs[1].text.contains("Eindstage front-end bij Org b"))
        #expect(letter.signature == "Daaf")
    }

    @Test func aDraftSurvivesBeingStored() throws {
        let draft = ApplicationBuilder.draft(for: vacancy, items: [item("b", .internships, "Stage")], name: "Daaf")
        let data = try JSONEncoder().encode(draft)
        let back = try JSONDecoder().decode(ApplicationDraft.self, from: data)
        #expect(back == draft)
    }
}
