import Foundation
import Testing
@testable import PAVECore

struct SkillCompassTests {
    private func vacancy(_ id: String, has: [String], misses: [String]) -> Vacancy {
        var vacancy = Vacancy(id: id, title: "Developer \(id)", company: "Bedrijf \(id)", source: .example)
        vacancy.matches = has.map { Vacancy.RequirementLink(skill: $0, requirement: "") }
        vacancy.skillGap = misses.map { Vacancy.RequirementLink(skill: $0, requirement: "") }
        return vacancy
    }

    @Test func whatYouMissMostComesFirst() {
        let vacancies = [vacancy("a", has: ["Swift"], misses: ["Scrum", "CI/CD"]), vacancy("b", has: ["Swift"], misses: ["scrum"]), vacancy("b", has: [], misses: ["Docker"])]
        var item = VaultItem(id: "i", category: .projects, title: "PAVE iOS-app", status: .verified)
        item.skills = ["Swift"]
        let compass = SkillCompass.build(vacancies: vacancies, items: [item])
        #expect(compass.vacancyCount == 2)
        #expect(compass.nextBest?.name == "Scrum")
        #expect(compass.nextBest?.count == 2)
        #expect(compass.missing.map(\.name) == ["Scrum", "CI/CD"])
        #expect(compass.have.first?.name == "Swift")
        #expect(compass.have.first?.evidence == ["PAVE iOS-app"])
        #expect(compass.have.first?.isVerified == true)
    }

    @Test func aSkillInYourVaultIsNoLongerMissing() {
        var item = VaultItem(id: "i", category: .certificates, title: "Scrum Foundation")
        item.skills = ["Scrum"]
        let compass = SkillCompass.build(vacancies: [vacancy("a", has: [], misses: ["Scrum"])], items: [item])
        #expect(compass.missing.isEmpty)
        #expect(compass.have.first?.evidence == ["Scrum Foundation"])
        #expect(compass.have.first?.isVerified == false)
    }
}
