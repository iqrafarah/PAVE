import Foundation
import Testing
@testable import PAVECore

struct SavedProfileTests {
    @Test func aStarterProfileTakesWhatTheRecipientUsuallyNeeds() {
        let items = [
            VaultItem(id: "d", category: .diplomas, title: "Propedeuse"),
            VaultItem(id: "w", category: .workExperience, title: "Bijbaan"),
            VaultItem(id: "r", category: .projects, title: "Afgewezen", status: .rejected),
        ]
        let profile = SavedProfile.starter(for: .education, items: items)
        #expect(profile.name == "Voor school")
        #expect(profile.itemIDs.contains("d"))
        #expect(!profile.itemIDs.contains("r"))
    }

    @Test func onlyWhatIsInTheProfileCanBeBrief() {
        let profile = SavedProfile(name: "Voor werkgevers", template: .employer, itemIDs: ["a", "b"], briefIDs: ["b", "gone"])
        #expect(profile.brief == ["b"])
        #expect(profile.problem == nil)
        #expect(SavedProfile(name: " ", template: .employer, itemIDs: ["a"]).problem == .noName)
        #expect(SavedProfile(name: "Leeg", template: .employer).problem == .nothingChosen)
    }

    @Test func briefSurvivesTheShareContent() throws {
        let content = ShareContent(profile: ShareProfile(name: "Ravi"), brief: ["b"])
        let back = try JSONDecoder().decode(ShareContent.self, from: JSONEncoder().encode(content))
        #expect(back.brief == ["b"])
    }
}

struct FairEmployerTests {
    @Test func aRealEmployerCarriesTheDayItsVacanciesWereRead() throws {
        let json = #"[{"slug":"ogd","name":"OGD ict-diensten","about":"ICT","is_example":false,"created_at":"2026-11-25T11:40:12.123+00:00","vacancies":[{"id":"v","title":"Traineeship IT","company":"OGD","source":"web","url":"https://werkenbij.ogd.nl/vacatures/traineeship-it","matches":[],"skillGap":[]}]}]"#
        let employer = try #require(try JSONDecoder().decode([FairEmployer].self, from: Data(json.utf8)).first)
        #expect(!employer.isExample)
        #expect(employer.addedAt != nil)
        #expect(employer.vacancies.first?.url?.host() == "werkenbij.ogd.nl")
    }
}
