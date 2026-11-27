import EventKit
import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct AylaNewActionsTests {
    private func plans() async -> (PlanModel, PavePlan) {
        var scrum = PavePlan(template: .empty, name: "Scrum halen")
        scrum.addStep(PavePlanStep(title: "Cursus kiezen"))
        scrum.addStep(PavePlanStep(title: "Proefexamen"))
        scrum.addStep(PavePlanStep(title: "Examen doen"))
        let model = PlanModel(service: LocalPlanService(fileURL: nil, seed: [scrum]))
        await model.load()
        return (model, scrum)
    }

    private func settled(_ check: () -> Bool) async {
        for _ in 0..<40 where !check() { try? await Task.sleep(for: .milliseconds(25)) }
    }

    @Test func calendarMomentsAreDaysTimesAndRepeats() throws {
        let day = try #require(AylaCalendarMoment(title: "Open dag", value: "2026-12-03"))
        #expect(day.isAllDay && day.repeats == nil)
        let time = try #require(AylaCalendarMoment(title: "Gesprek", value: "2026-12-03T14:30"))
        #expect(!time.isAllDay)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        #expect(calendar.component(.hour, from: time.date) == 14)
        let weekly = try #require(AylaCalendarMoment(title: "Plan", value: "2026-11-27T17:00 weekly"))
        #expect(weekly.repeats == .weekly)
        #expect(AylaCalendarMoment(title: "x", value: "volgende week") == nil)
        #expect(AylaCalendarMoment(title: "x", value: "2026-11-27 hourly") == nil)
    }

    @Test func aylasChangesFillTheEvidenceFormAndNothingElse() {
        var draft = VaultItemDraft(item: VaultItem(id: "a", category: .internships, title: "Stage", organisationName: "Kade"))
        draft.isCurrent = true
        draft.apply(aylaChanges: "eind: 2026-06-30; titel: Afstudeerstage; kleur: rood; start: geen datum")
        #expect(draft.title == "Afstudeerstage")
        #expect(draft.endDate == VaultDay("2026-06-30"))
        #expect(draft.isCurrent == false)
        #expect(draft.startDate == nil)
        #expect(draft.organisationName == "Kade")
    }

    @Test func aStepGetsADeadlineMovesAndKeepsItsEvidence() async {
        let (plans, scrum) = await plans()
        let actions = AylaPlanActions(plans: plans, chatPlan: scrum)
        #expect(actions.setDue("examen doen", to: "2026-12-15") == nil)
        await settled { plans.plan(id: scrum.id)?.steps.last?.due == "2026-12-15" }
        #expect(plans.plan(id: scrum.id)?.steps.last?.due == "2026-12-15")
        #expect(actions.setDue("examen doen", to: "ooit") != nil)

        #expect(AylaPlanActions(plans: plans, chatPlan: plans.plan(id: scrum.id)).moveStep("examen doen", before: "first") == nil)
        await settled { plans.plan(id: scrum.id)?.steps.first?.title == "Examen doen" }
        #expect(plans.plan(id: scrum.id)?.steps.map(\.title) == ["Examen doen", "Cursus kiezen", "Proefexamen"])

        let psm = VaultItem(id: "psm", category: .certificates, title: "PSM I")
        #expect(AylaPlanActions(plans: plans, chatPlan: plans.plan(id: scrum.id)).link(evidence: psm, toStep: "proefexamen") == nil)
        await settled { plans.plan(id: scrum.id)?.steps.last?.evidenceIDs == ["psm"] }
        let step = plans.plan(id: scrum.id)?.steps.last
        #expect(step?.evidenceIDs == ["psm"])
        #expect(step.flatMap(PlanMessages.stepExtras) == "1 bewijsstuk")
    }

    @Test func aPassedDeadlineShowsAsOverdueUntilTheStepIsDone() {
        var step = PavePlanStep(title: "Cv")
        step.due = "2026-01-01"
        #expect(PlanMessages.isOverdue(step, now: Date(timeIntervalSince1970: 1_800_000_000)))
        step.status = .done
        #expect(!PlanMessages.isOverdue(step, now: Date(timeIntervalSince1970: 1_800_000_000)))
    }

    @Test func applicationsReachAylaAsOneLineEachAndAreFoundByName() {
        var kade = ApplicationDraft(vacancy: Vacancy(id: "k", title: "Junior IT-consultant", company: "Kade", source: .example), cv: CVContent(name: "Ravi"), letter: LetterContent())
        var tracking = ApplicationTracking()
        tracking.set(.interview)
        kade.tracking = tracking
        let ogd = ApplicationDraft(vacancy: Vacancy(id: "o", title: "Traineeship IT", company: "OGD", source: .example), cv: CVContent(name: "Ravi"), letter: LetterContent())
        #expect(AylaPlanActions.applicationLines([kade, ogd]) == ["Junior IT-consultant bij Kade, interview", "Traineeship IT bij OGD, concept"])
        #expect(AylaPlanActions.application("kade", in: [kade, ogd])?.id == "k")
        #expect(AylaPlanActions.application("traineeship", in: [kade, ogd])?.id == "o")
    }
}
