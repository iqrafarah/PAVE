import Foundation
import PAVECore
import Testing

/// Profile, plans and vault rows through PostgREST, with the production row-level security: your own rows only, and
/// only after two-step verification.
@Suite(.localSupabase)
struct DataIntegrationTests {
    private func plan(_ name: String) -> PavePlan {
        PavePlan(
            template: PavePlanTemplate(id: "integration", name: name, steps: [.init("Eerste stap"), .init("Tweede stap")]),
            name: name
        )
    }

    private func draft(_ title: String) -> VaultItemDraft {
        var draft = VaultItemDraft(category: .projects)
        draft.title = title
        return draft
    }

    @Test func aNewAccountGetsAProfileAndExampleFolders() async throws {
        let user = try await TestUser.make("profile")
        _ = try await user.profile.profile()
        #expect(try await user.vault.contents().folders.count == 4)
    }

    @Test func thePreferredNameIsSavedOnTheProfile() async throws {
        let user = try await TestUser.make("name")
        try await user.profile.setPreferredName("Noor")
        #expect(try await user.profile.profile().preferredName == "Noor")
    }

    @Test func aPlanIsSavedReadBackAndDeleted() async throws {
        let user = try await TestUser.make("plan")
        let plan = plan("Stage vinden")
        try await user.plans.save(plan)

        let saved = try #require(try await user.plans.plans().first { $0.id == plan.id })
        #expect(saved.name == "Stage vinden")
        #expect(saved.steps.map(\.title) == ["Eerste stap", "Tweede stap"])

        try await user.plans.delete(id: plan.id)
        #expect(try await user.plans.plans().contains { $0.id == plan.id } == false)
    }

    @Test func aVaultItemIsAddedAndDeleted() async throws {
        let user = try await TestUser.make("vault")
        let id = try await user.vault.add(draft("Portfolio website"))
        let item = try #require(try await user.vault.contents().items.first { $0.id == id })
        #expect(item.title == "Portfolio website")
        #expect(item.status == .toVerify)

        try await user.vault.delete(item)
        #expect(try await user.vault.contents().items.contains { $0.id == id } == false)
    }

    @Test func anotherAccountCannotSeeYourPlansOrEvidence() async throws {
        async let owner = TestUser.make("owner")
        async let stranger = TestUser.make("stranger")
        let (a, b) = try await (owner, stranger)

        let plan = plan("Geheim plan")
        try await a.plans.save(plan)
        let itemID = try await a.vault.add(draft("Mijn diploma"))

        #expect(try await b.plans.plans().contains { $0.id == plan.id } == false)
        #expect(try await b.vault.contents().items.contains { $0.id == itemID } == false)
        // Deleting someone else's plan changes nothing for them.
        try? await b.plans.delete(id: plan.id)
        #expect(try await a.plans.plans().contains { $0.id == plan.id })
    }

    @Test func withoutTwoStepVerificationNothingCanBeSaved() async throws {
        let user = try await TestUser.make("aal1", twoStep: false)
        await #expect(throws: (any Error).self) { try await user.vault.add(draft("Zonder code")) }
        await #expect(throws: (any Error).self) { try await user.plans.save(plan("Zonder code")) }
    }
}
