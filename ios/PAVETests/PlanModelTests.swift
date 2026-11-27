import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct PlanModelTests {
    private struct FailingService: PlanService {
        var error: any Error = Failure()
        struct Failure: Error {}
        func plans() async throws -> [PavePlan] { throw error }
        func save(_ plan: PavePlan) async throws { throw error }
        func delete(id: String) async throws { throw error }
    }

    private func loadedModel(_ plans: [PavePlan] = [PavePlan(template: PlanTemplates.job), PavePlan(template: PlanTemplates.skill)]) async -> PlanModel {
        let model = PlanModel(service: LocalPlanService(fileURL: nil, seed: plans))
        await model.load()
        return model
    }

    /// Changes to steps are saved in the background; this waits until the change shows.
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<50 where !condition() { await Task.yield() }
    }

    @Test func aPlanFromATemplateIsCreatedAndKept() async {
        let model = await loadedModel([])
        let plan = await model.create(name: "  Mijn  doel ", from: PlanTemplates.internship)
        #expect(plan?.name == "Mijn doel")
        #expect(plan?.templateID == "internship")
        #expect(plan?.steps.count == PlanTemplates.internship.steps.count)
        #expect(plan?.currentStep?.title == PlanTemplates.internship.steps.first?.title)
        #expect(model.plans.count == 1)
        #expect(await model.create(name: "   ") == nil)
    }

    @Test func aPlanAylaMadeHasTheChatAndIsMadeOnce() async throws {
        let model = await loadedModel([])
        let action = AylaReply.ProposedAction(
            id: "proposal", kind: .createPlan, summary: "", expiresAt: .now.addingTimeInterval(60),
            newPlan: .init(name: "Stage vinden", goal: "Een stage", steps: [.init(title: "Cv bijwerken", kind: .document), .init(title: "Solliciteren")])
        )
        let plan = try #require(await model.create(from: action, conversationID: "chat", title: "Mijn stage"))
        #expect(plan.steps.count == 2)
        #expect(model.plan(containing: "chat")?.id == plan.id)
        #expect(await model.create(from: action, conversationID: "chat") == nil)
        #expect(model.plans.count == 1)
    }

    @Test func aPlanWithTheSameNameIsNeverMadeBesideIt() async throws {
        let model = await loadedModel([])
        func proposal(_ id: String, _ name: String) -> AylaReply.ProposedAction {
            AylaReply.ProposedAction(id: id, kind: .createPlan, summary: "", expiresAt: .now.addingTimeInterval(60),
                                     newPlan: .init(name: name, steps: [.init(title: "Eisen uitzoeken"), .init(title: "Aanmelden")]))
        }
        let first = try #require(await model.create(from: proposal("one", "KLM-piloot worden"), conversationID: "chat"))
        #expect(await model.create(from: proposal("two", "KLM-piloot worden"), conversationID: "chat") == nil)
        #expect(await model.create(from: proposal("three", "klm piloot worden."), conversationID: "other") == nil)
        #expect(model.plans.count == 1)
        #expect(model.plan(containing: "chat")?.id == first.id)
        // A chat without a plan that asked for the same plan joins the one that is there.
        await eventually { model.plan(containing: "other") != nil }
        #expect(model.plan(containing: "other")?.id == first.id)
    }

    @Test func aNewPlanInAPlansChatTakesTheChatAlong() async throws {
        let model = await loadedModel()
        let old = try #require(model.plans.first)
        model.attach(conversationID: "chat", to: old.id)
        await eventually { model.plan(containing: "chat") != nil }
        let action = AylaReply.ProposedAction(
            id: "proposal", kind: .createPlan, summary: "", expiresAt: .now.addingTimeInterval(60),
            newPlan: .init(name: "Nieuw", steps: [.init(title: "Een"), .init(title: "Twee")])
        )
        let plan = try #require(await model.create(from: action, conversationID: "chat"))
        await eventually { model.plan(id: old.id)?.contains(conversationID: "chat") == false }
        #expect(model.plan(id: old.id)?.contains(conversationID: "chat") == false)
        #expect(model.plan(containing: "chat")?.id == plan.id)
    }

    @Test func renamingAndDeleting() async throws {
        let model = await loadedModel()
        let id = try #require(model.plans.first?.id)
        #expect(await model.rename(id, to: "Nieuwe naam", goal: "Nieuw doel"))
        #expect(model.plan(id: id)?.name == "Nieuwe naam")
        #expect(model.plan(id: id)?.goal == "Nieuw doel")
        model.openPlanID = id
        await model.delete(id)
        #expect(model.plan(id: id) == nil)
        #expect(model.openPlanID == nil)
    }

    @Test func finishingAStepMovesThePlanOnAndIsSaved() async throws {
        let service = LocalPlanService(fileURL: nil, seed: [PavePlan(template: PlanTemplates.job)])
        let model = PlanModel(service: service)
        await model.load()
        let plan = try #require(model.plans.first)
        let next = plan.steps[1].id
        model.completeCurrentStep(in: plan.id)
        await eventually { model.plan(id: plan.id)?.currentStep?.id == next }
        #expect(model.plan(id: plan.id)?.doneCount == 1)
        let saved = try await service.plans().first
        #expect(saved?.currentStep?.id == next)
    }

    @Test func stepsCanBeAddedChangedSkippedAndRemoved() async throws {
        let model = await loadedModel([PavePlan(template: PlanTemplates.career)])
        let plan = try #require(model.plans.first)
        model.addStep(PavePlanStep(title: "Eigen stap", kind: .contact), to: plan.id)
        await eventually { model.plan(id: plan.id)?.steps.count == plan.steps.count + 1 }
        var changed = try #require(model.plan(id: plan.id)?.steps.last)
        changed.title = "Mentor bellen"
        model.updateStep(changed, in: plan.id)
        await eventually { model.plan(id: plan.id)?.steps.last?.title == "Mentor bellen" }
        model.setStatus(.skipped, of: plan.steps[1].id, in: plan.id)
        await eventually { model.plan(id: plan.id)?.steps[1].status == .skipped }
        #expect(model.plan(id: plan.id)?.totalCount == plan.steps.count)
        model.removeStep(changed.id, from: plan.id)
        await eventually { model.plan(id: plan.id)?.steps.count == plan.steps.count }
        #expect(model.plan(id: plan.id)?.steps.contains { $0.title == "Mentor bellen" } == false)
    }

    @Test func theActivePlanFollowsTheChat() async throws {
        let model = await loadedModel()
        let plan = try #require(model.plans.first)
        #expect(model.activePlan(conversationID: nil, newChatPlanID: plan.id)?.id == plan.id)
        #expect(model.activePlan(conversationID: "c1", newChatPlanID: plan.id) == nil)
        model.attach(conversationID: "c1", title: "Eerste gesprek", to: plan.id)
        await eventually { model.plan(containing: "c1") != nil }
        #expect(model.activePlan(conversationID: "c1", newChatPlanID: nil)?.id == plan.id)
    }

    @Test func aStepAylaChangedShowsAtOnce() async throws {
        let model = await loadedModel()
        let plan = try #require(model.plans.first)
        model.apply(AylaReply.PlanStepUpdate(planId: plan.id, stepId: plan.steps[0].id, status: .done))
        #expect(model.plan(id: plan.id)?.steps[0].status == .done)
        #expect(model.plan(id: plan.id)?.currentStep?.id == plan.steps[1].id)
        // A plan that is not there changes nothing.
        model.apply(AylaReply.PlanStepUpdate(planId: "other", stepId: "s", status: .done))
        #expect(model.plans.count == 2)
    }

    @Test func aChangeThatCannotBeSavedIsUndone() async throws {
        let model = PlanModel(service: FailingService())
        await model.load()
        #expect(model.problem == PlanMessages.loadFailed)
        model.problem = nil
        #expect(await model.create(name: "Plan") == nil)
        #expect(model.plans.isEmpty)
        #expect(model.problem == PlanMessages.saveFailed)
    }

    @Test func beforeTheMigrationPlansAreNotAvailable() async {
        let model = PlanModel(service: FailingService(error: PlanServiceError.notSetUp))
        await model.load()
        #expect(!model.isAvailable)
        #expect(model.problem == nil)
        #expect(await model.create(name: "Plan") == nil)
        #expect(model.problem == PlanMessages.notAvailable)
    }

    @Test func everyTemplateIsUsable() {
        let templates = PlanTemplates.all.filter { !$0.steps.isEmpty }
        #expect(templates.count == 7)
        #expect(Set(PlanTemplates.all.map(\.id)).count == PlanTemplates.all.count)
        for template in templates {
            #expect(!template.summary.isEmpty)
            #expect(PlanTemplates.icon(for: template.id) != .iconMap)
            #expect(template.steps.count >= 5)
            #expect(template.steps.allSatisfy { PavePlanStep.Kind.choosable.contains($0.kind) && !$0.summary.isEmpty })
            #expect(template.steps.allSatisfy { PavePlan.cleanName($0.title) == $0.title })
        }
        // Together they lead to every part of PAVE: Ayla, the vault, the profile and contact.
        let kinds = Set(templates.flatMap { $0.steps.map(\.kind) })
        #expect(kinds.isSuperset(of: [.conversation, .evidence, .profile, .contact]))
        #expect(PavePlanStep.Kind.evidence.destination == .vault)
        #expect(PavePlanStep.Kind.profile.destination == .profile)
        #expect(PavePlanStep.Kind.contact.destination == .notifications)
    }

    @Test func everyNumberLeavesSkippedStepsOut() {
        var plan = PavePlan(template: PlanTemplates.job)
        plan.completeCurrentStep()
        plan.setStatus(.skipped, of: plan.steps[1].id)
        #expect(PlanMessages.stepNumber(plan) == "Stap 2 van 6")
        #expect(PlanMessages.progress(plan) == "1 van 6")
        #expect(plan.progress == 1.0 / 6.0)
    }

    @Test func theLockScreenShowsOnlyNumbersAndTheKindOfStepUnlessNamesAreAllowed() {
        var plan = PavePlan(template: PlanTemplates.job)
        plan.completeCurrentStep()
        plan.setStatus(.skipped, of: plan.steps[1].id)
        let hidden = PlanActivityController.state(for: plan, showsNames: false)
        #expect(hidden.planName == nil)
        #expect(hidden.stepTitle == nil)
        #expect(hidden.title == "Je plan")
        #expect(hidden.line == "Stap 2 van 6 · Bewijs in je kluis")
        #expect(hidden.short == "1/6")
        #expect(hidden.symbol == "folder")
        #expect(!hidden.line.contains(plan.name))
        let named = PlanActivityController.state(for: plan, showsNames: true)
        #expect(named.title == "Een baan vinden")
        #expect(named.line == "Bewijs in je kluis")
        for step in plan.steps where step.status != .done && step.status != .skipped { plan.setStatus(.done, of: step.id) }
        let finished = PlanActivityController.state(for: plan, showsNames: false)
        #expect(finished.isFinished)
        #expect(finished.short == "Klaar")
        #expect(finished.progress == 1)
    }

    @Test func aPlanOnTheLockScreenOpensThePlanScreen() {
        #expect(PaveLink(url: PaveLink.plan.url) == .plan)
    }

    @Test func deletedOrLockedChatsAreNotShownInAPlan() {
        var plan = PavePlan(name: "Plan")
        plan.attach(conversationID: "open", title: "Oud")
        plan.attach(conversationID: "locked")
        plan.attach(conversationID: "gone")
        let list = AylaConversationList(conversations: [
            AylaConversation(id: "open", title: "Nieuw", updatedAt: .now),
            AylaConversation(id: "locked", title: "Geheim", updatedAt: .now, isLocked: true),
        ])
        #expect(plan.liveConversations(in: list, isComplete: true).map(\.title) == ["Nieuw"])
        #expect(plan.liveConversations(in: list, isComplete: false).map(\.id).sorted() == ["gone", "open"])
    }
}
