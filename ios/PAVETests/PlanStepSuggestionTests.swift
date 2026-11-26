import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct PlanStepSuggestionTests {
    private func model() async -> PlanModel {
        var talk = PavePlan(template: .empty, name: "Oefenen")
        talk.addStep(PavePlanStep(id: "t1", title: "Oefengesprek", kind: .conversation))
        var vault = PavePlan(template: .empty, name: "Scrum halen")
        vault.addStep(PavePlanStep(id: "v1", title: "Certificaat in je kluis", kind: .evidence))
        vault.addStep(PavePlanStep(id: "v2", title: "Solliciteren"))
        let model = PlanModel(service: LocalPlanService(fileURL: nil, seed: [talk, vault]))
        await model.load()
        return model
    }

    private func settled(_ check: () -> Bool) async {
        for _ in 0..<40 where !check() { try? await Task.sleep(for: .milliseconds(25)) }
    }

    @Test func evidenceAsksThePlanWhoseStepItFinishesAndOneTapFinishesIt() async throws {
        let model = await model()
        model.notice(.evidenceAdded(itemID: "item"))
        let suggestion = try #require(model.suggestion)
        #expect(suggestion.stepID == "v1")
        #expect(model.plan(id: suggestion.planID)?.currentStep?.id == "v1")

        model.acceptSuggestion()
        #expect(model.suggestion == nil)
        await settled { model.plan(id: suggestion.planID)?.currentStep?.id == "v2" }
        let plan = try #require(model.plan(id: suggestion.planID))
        #expect(plan.currentStep?.id == "v2")
        #expect(plan.steps.first?.evidenceIDs == ["item"])
    }

    @Test func somethingThatFitsNoStepAsksNothingAndNotYetLeavesTheStep() async {
        let model = await model()
        model.notice(.applicationSent(vacancyID: "v"))
        #expect(model.suggestion == nil)

        model.notice(.practiceFinished(vacancyID: "v"))
        #expect(model.suggestion?.stepID == "t1")
        model.dismissSuggestion()
        #expect(model.suggestion == nil)
        #expect(model.plans.allSatisfy { !$0.isFinished })
    }
}
