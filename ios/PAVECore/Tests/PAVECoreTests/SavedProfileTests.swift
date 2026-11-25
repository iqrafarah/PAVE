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
