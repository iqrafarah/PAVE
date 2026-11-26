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

    @Test func everyPartIsNewestFirstAndTheSkillsOfTheVacancyLead() {
        var current = item("d", .workExperience, "Bijbaan", skills: ["Plannen"])
        current.startDate = VaultDay(year: 2023, month: 9, day: 1)
        current.isCurrent = true
        var newerCurrent = item("e", .internships, "Afstudeerstage")
        newerCurrent.startDate = VaultDay(year: 2026, month: 9, day: 1)
        newerCurrent.isCurrent = true
        let items = [
            item("b", .internships, "Eindstage front-end", skills: ["Swift"], end: VaultDay(year: 2024, month: 1, day: 1)),
            item("a", .workExperience, "Teamleider avondploeg", skills: ["Plannen"], end: VaultDay(year: 2025, month: 6, day: 1)),
            current, newerCurrent,
            item("c", .diplomas, "HBO-ICT", end: VaultDay(year: 2026, month: 7, day: 1)),
        ]
        let draft = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf")
        let experience = draft.cv.sections.first { $0.kind == .experience }
        #expect(experience?.entries.map(\.sourceItemID) == ["e", "d", "a", "b"])
        #expect(draft.cv.skills.first == "Swift")
        #expect(draft.cv.headline == "Student HBO-ICT")
        #expect(draft.cv.visibleSections.map(\.kind) == [.experience, .education])
    }

    @Test func aDiplomaOrCertificateIsNameSchoolAndYear() {
        var diploma = item("c", .diplomas, "Vwo-diploma", end: VaultDay(year: 2022, month: 7, day: 1))
        diploma.description = "Je haalde je vwo-diploma."
        diploma.organisationName = "Stedelijk College Eindhoven"
        diploma.organisationLocation = "Eindhoven"
        var stage = item("b", .internships, "Stage")
        stage.description = "Websites gebouwd in Vue."
        stage.organisationName = "Studio Noord"
        stage.organisationLocation = "Tilburg"
        let draft = ApplicationBuilder.draft(for: vacancy, items: [diploma, stage], name: "Daaf")
        let education = draft.cv.sections.first { $0.kind == .education }?.entries.first
        let experience = draft.cv.sections.first { $0.kind == .experience }?.entries.first
        #expect(education?.description == "")
        #expect(education?.organisation == "Stedelijk College Eindhoven")
        #expect(experience?.description == "Websites gebouwd in Vue.")
        #expect(experience?.organisation == "Studio Noord, Tilburg")
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

    @Test func writingItYourselfKeepsTheVaultButLeavesTheTexts() {
        let items = [item("b", .internships, "Eindstage front-end", skills: ["Swift"])]
        let draft = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf", template: .frame, writesItself: true)
        #expect(draft.cv.visibleSections.count == 1)
        #expect(draft.cv.profile.isEmpty)
        #expect(draft.letter.paragraphs.count == 3)
        #expect(draft.letter.paragraphs.allSatisfy { $0.text.isEmpty })
        #expect(draft.template == .frame)
        #expect(draft.palette == .mono)
        #expect(!draft.showsPhoto)
    }

    @Test func anUnknownTemplateFromAnOlderVersionFallsBack() throws {
        let json = Data(#"["calm","pink"]"#.utf8)
        let decoded = try JSONDecoder().decode([String].self, from: json)
        let template = try JSONDecoder().decode(ApplicationTemplate.self, from: Data("\"\(decoded[0])\"".utf8))
        let palette = try JSONDecoder().decode(ApplicationPalette.self, from: Data("\"\(decoded[1])\"".utf8))
        #expect(template == .sage)
        #expect(palette == .pave)
    }

    @Test func aDraftSurvivesBeingStored() throws {
        let draft = ApplicationBuilder.draft(for: vacancy, items: [item("b", .internships, "Stage")], name: "Daaf")
        let data = try JSONEncoder().encode(draft)
        let back = try JSONDecoder().decode(ApplicationDraft.self, from: data)
        #expect(back == draft)
    }
}
