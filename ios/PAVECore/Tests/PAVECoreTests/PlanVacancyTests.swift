import Foundation
import Testing
@testable import PAVECore

struct PlanVacancyTests {
    private var vacancy: Vacancy {
        var vacancy = Vacancy(id: "v1", title: "Junior IT-consultant", company: "Kade", source: .example)
        vacancy.summary = "Je adviseert klanten over cloud."
        vacancy.skillGap = [
            Vacancy.RequirementLink(skill: "Scrum", requirement: "Ervaring met Scrum"),
            Vacancy.RequirementLink(skill: "CI/CD", requirement: ""),
        ]
        return vacancy
    }

    @Test func aPlanForAVacancyHasAStepForWhatIsMissingAndForTheApplication() {
        let plan = PavePlan(template: PlanVacancy.template(for: vacancy))
        #expect(plan.name == "Junior IT-consultant bij Kade")
        #expect(plan.steps.map(\.title).contains("Werk aan Scrum"))
        #expect(plan.steps.map(\.title).contains("Werk aan CI/CD"))
        #expect(plan.steps.first { $0.kind == .document }?.metadata[PlanVacancy.idKey] == "v1")
        #expect(PlanVacancy.vacancyID(of: plan) == "v1")
    }

    @Test func thePlanRemembersTheVacancyForAylaAndForOpeningTheApplication() {
        let plan = PavePlan(template: PlanVacancy.template(for: vacancy))
        #expect(PlanVacancy.job(of: plan) == PlanStepsRequest.Job(title: "Junior IT-consultant", company: "Kade", summary: "Je adviseert klanten over cloud.", missing: ["Scrum", "CI/CD"]))
        #expect(PlanVacancy.vacancy(of: plan)?.id == "v1")
        #expect(PlanVacancy.job(of: PavePlan(template: .empty, name: "Los plan")) == nil)
    }

    @Test func aylaOnlyGetsTitlesOfEvidenceSheMaySee() {
        var allowed = VaultItem(id: "i1", category: .diplomas, title: "Propedeuse HBO-ICT", status: .verified)
        allowed.aylaAllowedAt = .now
        allowed.skills = ["Python", "python"]
        let hidden = VaultItem(id: "i2", category: .projects, title: "Geheim project")
        let request = PlanStepsRequest(name: "Baan", goal: "Werk vinden", existing: ["Cv schrijven"], items: [allowed, hidden])
        #expect(request.evidence == [PlanStepsRequest.Evidence(title: "Propedeuse HBO-ICT", category: "diplomas", verified: true)])
        #expect(request.skills == ["Python"])
        #expect(request.evidenceCount == 1)
    }

    @Test func aProposalBecomesStepsAndAnUnknownKindStaysAStep() throws {
        let data = Data(#"{"steps":[{"title":"  Leer de basis van Scrum ","summary":"De vacature vraagt erom.","kind":"action"},{"title":"","kind":"general"},{"title":"Iets nieuws","kind":"toekomst"}]}"#.utf8)
        let steps = try JSONDecoder().decode(PlanStepsProposal.self, from: data).templateSteps
        #expect(steps.map(\.title) == ["Leer de basis van Scrum", "Iets nieuws"])
        #expect(steps[0].kind == .action)
    }

    @Test func aPlanCanBelongToAProject() {
        var plan = PavePlan(template: .empty, name: "Plan")
        #expect(plan.projectID == nil)
        plan.projectID = "p1"
        #expect(plan.metadata["projectID"] == "p1")
        plan.projectID = nil
        #expect(plan.metadata["projectID"] == nil)
    }
}
