import Foundation
import Testing
@testable import PAVECore

struct PlanStepExtrasTests {
    private func plan() -> PavePlan {
        PavePlan(name: "Scrum", steps: [PavePlanStep(id: "a", title: "Cursus kiezen"), PavePlanStep(id: "b", title: "Examen"), PavePlanStep(id: "c", title: "Bewijs")])
    }

    @Test func aStepMovesBeforeAnotherOrToTheEndAndTheActiveStepStays() {
        var plan = plan()
        plan.normalize()
        plan.moveStep(id: "c", before: "a")
        #expect(plan.steps.map(\.id) == ["c", "a", "b"])
        #expect(plan.currentStep?.id == "a")
        plan.moveStep(id: "c", before: nil)
        #expect(plan.steps.map(\.id) == ["a", "b", "c"])
    }

    @Test func aDeadlineAndEvidenceAreKeptWithTheStep() {
        var step = PavePlanStep(title: "Examen")
        step.due = "2026-12-15"
        step.evidenceIDs = ["x", "y"]
        #expect(step.metadata[PavePlanStep.dueKey] == "2026-12-15")
        #expect(step.metadata[PavePlanStep.evidenceKey] == "x,y")
        step.evidenceIDs = []
        #expect(step.metadata[PavePlanStep.evidenceKey] == nil)
    }

    @Test func aStepForWhatYouAreDoingComesRightAfterIt() {
        var plan = plan()
        plan.normalize()
        plan.addStepAfterCurrent(PavePlanStep(id: "x", title: "Aviation bij HvA bekijken"))
        #expect(plan.steps.map(\.id) == ["a", "x", "b", "c"])
        #expect(plan.currentStep?.id == "a")
    }
}
