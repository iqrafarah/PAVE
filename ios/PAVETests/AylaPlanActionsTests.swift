import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct AylaPlanActionsTests {
    private func model() async -> (PlanModel, PavePlan, PavePlan) {
        var stage = PavePlan(template: .empty, name: "Stage vinden in Eindhoven")
        stage.addStep(PavePlanStep(title: "Je cv bijwerken"))
        stage.addStep(PavePlanStep(title: "Stageplekken zoeken"))
        var scrum = PavePlan(template: .empty, name: "Scrum halen")
        scrum.addStep(PavePlanStep(title: "Cursus kiezen"))
        let plans = PlanModel(service: LocalPlanService(fileURL: nil, seed: [stage, scrum]))
        await plans.load()
        return (plans, stage, scrum)
    }

    private func settled(_ plans: PlanModel, _ check: () -> Bool) async {
        for _ in 0..<40 where !check() { try? await Task.sleep(for: .milliseconds(25)) }
    }

    @Test func aPlanIsFoundByYourOwnWords() async {
        let (plans, stage, scrum) = await model()
        let actions = AylaPlanActions(plans: plans, chatPlan: nil)
        #expect(actions.plan(named: "mijn plan voor de stage")?.id == nil || actions.plan(named: "stage vinden")?.id == stage.id)
        #expect(actions.plan(named: "Scrum halen")?.id == scrum.id)
        #expect(actions.plan(named: nil) == nil)
        #expect(AylaPlanActions(plans: plans, chatPlan: scrum).plan(named: nil)?.id == scrum.id)
    }

    @Test func aStepIsAddedToTheNamedPlanAndNotTwice() async {
        let (plans, _, scrum) = await model()
        let actions = AylaPlanActions(plans: plans, chatPlan: nil)
        #expect(actions.addStep("Een proefexamen doen", toPlanNamed: "Scrum halen") == nil)
        await settled(plans) { plans.plan(id: scrum.id)?.steps.count == 2 }
        #expect(plans.plan(id: scrum.id)?.steps.last?.title == "Een proefexamen doen")
        #expect(AylaPlanActions(plans: plans, chatPlan: nil).addStep("een proefexamen doen", toPlanNamed: "Scrum halen") != nil)
        #expect(actions.addStep("Iets", toPlanNamed: "Bestaat niet") != nil)
    }

    @Test func aStepIsTickedOffFromAnyChatAndRemovedByName() async {
        let (plans, stage, _) = await model()
        let actions = AylaPlanActions(plans: plans, chatPlan: nil)
        #expect(actions.markStep("cv bijwerken", as: "done") == nil)
        await settled(plans) { plans.plan(id: stage.id)?.steps.first?.status == .done }
        #expect(plans.plan(id: stage.id)?.steps.first?.status == .done)
        #expect(actions.markStep("cv bijwerken", as: "misschien") != nil)
        #expect(actions.markStep("bestaat niet", as: "done") != nil)
        #expect(AylaPlanActions(plans: plans, chatPlan: nil).removeStep("Stageplekken zoeken") == nil)
        await settled(plans) { plans.plan(id: stage.id)?.steps.count == 1 }
        #expect(plans.plan(id: stage.id)?.steps.count == 1)
    }

    @Test func aPlanGoesIntoAProjectWithItsChatsAndOutAgain() async {
        let (plans, stage, _) = await model()
        let projects = [AylaProject(id: "p1", name: "Afstuderen"), AylaProject(id: "p2", name: "Sollicitatie Kade")]
        var moved: String?
        let actions = AylaPlanActions(plans: plans, chatPlan: nil)
        #expect(actions.link(planNamed: "Stage vinden", toProjectNamed: "afstuderen", projects: projects) { _, project in moved = project?.id } == nil)
        await settled(plans) { plans.plan(id: stage.id)?.projectID == "p1" }
        #expect(plans.plan(id: stage.id)?.projectID == "p1")
        #expect(moved == "p1")
        #expect(actions.link(planNamed: "Stage vinden", toProjectNamed: "Onbekend", projects: projects) { _, _ in } != nil)
        #expect(actions.link(planNamed: "Stage vinden", toProjectNamed: "none", projects: projects) { _, _ in } == nil)
        await settled(plans) { plans.plan(id: stage.id)?.projectID == nil }
        #expect(plans.plan(id: stage.id)?.projectID == nil)
    }

    @Test func aylaGetsOneLinePerPlanWithoutGoals() {
        var plan = PavePlan(template: .empty, name: "Scrum halen", goal: "Geheim doel")
        plan.addStep(PavePlanStep(title: "Cursus kiezen", status: .active))
        plan.addStep(PavePlanStep(title: "Examen doen"))
        #expect(AylaPlanActions.lines([plan]) == ["Scrum halen (0 van 2 stappen, nu: Cursus kiezen)"])
    }
}
