import Foundation
import Testing
@testable import PAVECore

struct PlanProgressEventTests {
    private func plan(current kind: PavePlanStep.Kind) -> PavePlan {
        var plan = PavePlan(name: "Scrum", steps: [PavePlanStep(id: "a", title: "Nu", kind: kind), PavePlanStep(id: "b", title: "Daarna")])
        plan.normalize()
        return plan
    }

    @Test func whatYouDidFinishesTheStepOnlyWhenItIsWhatTheStepAsks() {
        #expect(plan(current: .evidence).stepFinished(by: .evidenceAdded(itemID: "x"))?.id == "a")
        #expect(plan(current: .verification).stepFinished(by: .verificationRequested(itemID: "x"))?.id == "a")
        #expect(plan(current: .document).stepFinished(by: .applicationSent(vacancyID: "v"))?.id == "a")
        #expect(plan(current: .conversation).stepFinished(by: .practiceFinished(vacancyID: "v"))?.id == "a")
        #expect(plan(current: .research).stepFinished(by: .evidenceAdded(itemID: "x")) == nil)
        #expect(plan(current: .evidence).stepFinished(by: .applicationSent(vacancyID: "v")) == nil)
    }

    @Test func aFinishedPlanOffersNothing() {
        var done = plan(current: .evidence)
        done.setStatus(.done, of: "a")
        done.setStatus(.done, of: "b")
        #expect(done.stepFinished(by: .evidenceAdded(itemID: nil)) == nil)
    }

    @Test func finishingAStepKeepsItsEvidenceAndMovesOn() {
        var plan = plan(current: .evidence)
        plan.finishStep(id: "a", evidenceID: "item")
        plan.finishStep(id: "a", evidenceID: "item")
        #expect(plan.steps[0].status == .done)
        #expect(plan.steps[0].evidenceIDs == ["item"])
        #expect(plan.currentStep?.id == "b")
    }
}
