import Foundation
import Testing
@testable import PAVECore

struct PlanTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private let template = PavePlanTemplate(id: "t", name: "Doel", steps: [
        .init("Een", kind: .conversation),
        .init("Twee", kind: .evidence),
        .init("Drie", kind: PavePlanStep.Kind(rawValue: "somethingNew")),
    ])

    @Test func aNewPlanStartsAtItsFirstStep() {
        let plan = PavePlan(template: template, now: now)
        #expect(plan.steps.map(\.status) == [.active, .upcoming, .upcoming])
        #expect(plan.currentStep?.title == "Een")
        #expect(plan.currentNumber == 1)
        #expect(plan.progress == 0)
    }

    @Test func finishingAStepMakesTheNextOneActive() {
        var plan = PavePlan(template: template, now: now)
        plan.completeCurrentStep(at: now)
        #expect(plan.steps.map(\.status) == [.done, .active, .upcoming])
        #expect(plan.steps[0].completedAt == now)
        #expect(plan.doneCount == 1)
        #expect(abs(plan.progress - 1.0 / 3.0) < 0.0001)
    }

    @Test func onlyOneStepIsActiveAtATime() {
        var plan = PavePlan(template: template, now: now)
        plan.setStatus(.active, of: plan.steps[2].id)
        #expect(plan.steps.map(\.status) == [.upcoming, .upcoming, .active])
    }

    @Test func reopeningAStepClearsWhenItWasDone() {
        var plan = PavePlan(template: template, now: now)
        plan.completeCurrentStep(at: now)
        plan.setStatus(.upcoming, of: plan.steps[0].id)
        #expect(plan.steps[0].completedAt == nil)
        #expect(plan.steps.count { $0.status == .active } == 1)
    }

    @Test func skippedStepsDoNotCountAndAPlanCanBeFinished() {
        var plan = PavePlan(template: template, now: now)
        plan.setStatus(.skipped, of: plan.steps[1].id)
        #expect(plan.totalCount == 2)
        plan.completeCurrentStep()
        plan.completeCurrentStep()
        #expect(plan.isFinished)
        #expect(plan.currentStep == nil)
        #expect(plan.progress == 1)
        #expect(plan.currentNumber == 2)
    }

    @Test func theStepNumberLeavesSkippedStepsOutLikeTheProgress() {
        var plan = PavePlan(template: template, now: now)
        plan.setStatus(.skipped, of: plan.steps[0].id)
        // Skipping the first makes the second the current step: step 1 of 2, nothing done yet.
        #expect(plan.currentStep?.title == "Twee")
        #expect(plan.currentNumber == 1)
        #expect(plan.totalCount == 2)
        #expect(plan.doneCount == 0)
        plan.completeCurrentStep()
        #expect(plan.currentNumber == 2)
        #expect(plan.doneCount == 1)
        #expect(plan.progress == 0.5)
    }

    @Test func idsAreLowerCaseAndTheTemplateIsKept() {
        let plan = PavePlan(template: template, now: now)
        #expect(plan.id == plan.id.lowercased())
        #expect(plan.steps.allSatisfy { $0.id == $0.id.lowercased() })
        #expect(plan.templateID == "t")
        #expect(PavePlan(template: .empty, name: "Leeg").templateID == nil)
    }

    @Test func rowsFromSupabaseBecomePlans() throws {
        let plans = Data("""
        [{"id":"p1","name":"Een baan vinden","goal":"Werk","template_id":"job","metadata":{"vacancyId":"v1","count":2},"completed_at":null,
          "created_at":"2026-11-20T10:00:00.123456+00:00","updated_at":"2026-11-25T10:00:00+00:00",
          "plan_steps":[
            {"id":"s2","position":1,"title":"Twee","summary":"","kind":"vacancy","status":"active","completed_at":null,"metadata":{}},
            {"id":"s1","position":0,"title":"Een","summary":"Eerst","kind":"conversation","status":"done","completed_at":"2026-11-21T10:00:00+00:00","metadata":null}
          ]}]
        """.utf8)
        let chats = Data("""
        [{"id":"c1","title":"Gesprek","plan_id":"p1","plan_step_id":"s2","created_at":"2026-11-22T10:00:00+00:00"}]
        """.utf8)
        let plan = try #require(SupabasePlanService.decode(plans: plans, chats: chats).first)
        #expect(plan.steps.map(\.id) == ["s1", "s2"])
        #expect(plan.steps[1].kind.rawValue == "vacancy")
        #expect(plan.steps[0].completedAt != nil)
        #expect(plan.templateID == "job")
        #expect(plan.metadata == ["vacancyId": "v1", "count": "2"])
        #expect(plan.conversations.map(\.id) == ["c1"])
        #expect(plan.steps[1].conversationID == "c1")
        #expect(plan.updatedAt == SupabasePlanService.date(from: "2026-11-25T10:00:00+00:00"))
    }

    @Test func aMissingTableMeansTheMigrationHasNotRun() {
        let body = Data(#"{"code":"PGRST205","message":"Could not find the table"}"#.utf8)
        #expect(SupabasePlanService.error(status: 404, body: body) == .notSetUp)
        #expect(SupabasePlanService.error(status: 500, body: Data()) == .failed(status: 500))
    }

    @Test func aNewChatInAPlanSaysWhichPlanAndStep() throws {
        let new = AylaRequest(text: "Hoi", device: .phone, input: .text, planId: "p1", planStepId: "s1")
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(new)) as? [String: Any])
        #expect(json["planId"] as? String == "p1")
        #expect(json["planStepId"] as? String == "s1")
        let existing = AylaRequest(conversationId: "c1", text: "Hoi", device: .phone, input: .text, planId: "p1", planStepId: "s1")
        let other = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(existing)) as? [String: Any])
        #expect(other["planId"] == nil)
        #expect(other["planStepId"] == nil)
    }

    @Test func aReplyCanCarryAPlanUpdate() throws {
        let json = Data("""
        {"version":1,"id":"r","conversationId":"c","text":"Goed gedaan!","blocks":[],"usedData":[],
         "proposedAction":{"id":"a","kind":"updatePlan","summary":"Stap afgerond","expiresAt":"2026-11-26T10:00:00Z",
           "planStep":{"planId":"p1","stepId":"s1","status":"done"}}}
        """.utf8)
        let reply = try AylaReply.decode(json)
        #expect(reply.proposedAction?.kind == .updatePlan)
        #expect(reply.proposedAction?.planStep == AylaReply.PlanStepUpdate(planId: "p1", stepId: "s1", status: .done))
    }

    @Test func completingAPlanFinishesWhatIsLeftAndReopeningGoesOnFromTheLastStep() {
        var plan = PavePlan(template: template, now: now)
        plan.setStatus(.skipped, of: plan.steps[1].id)
        plan.complete(at: now)
        #expect(plan.isFinished)
        #expect(plan.completedAt == now)
        #expect(plan.steps.map(\.status) == [.done, .skipped, .done])
        #expect(plan.progress == 1)
        plan.reopen()
        #expect(!plan.isFinished)
        #expect(plan.completedAt == nil)
        #expect(plan.currentStep?.title == "Drie")
    }

    @Test func finishingTheLastStepFinishesThePlanAndReopeningAStepUndoesThat() {
        var plan = PavePlan(template: template, now: now)
        plan.completeCurrentStep(at: now)
        plan.completeCurrentStep(at: now)
        #expect(plan.completedAt == nil)
        plan.completeCurrentStep(at: now)
        #expect(plan.completedAt != nil)
        plan.setStatus(.upcoming, of: plan.steps[2].id)
        #expect(plan.completedAt == nil)
        #expect(plan.currentStep?.title == "Drie")
    }

    @Test func anEmptyPlanCanBeCompletedByHand() {
        var plan = PavePlan(name: "Leeg")
        #expect(!plan.isFinished)
        plan.complete(at: now)
        #expect(plan.isFinished)
        plan.normalize()
        #expect(plan.isFinished)
    }

    @Test func anOlderAylaServerThatDoesNotKnowPlansIsRecognised() {
        let rejected = Data(#"{"error":"invalid_request","detail":"unknown field planId"}"#.utf8)
        #expect(SupabaseAylaService.rejectsPlanFields(status: 400, body: rejected))
        #expect(!SupabaseAylaService.rejectsPlanFields(status: 400, body: Data(#"{"error":"invalid_request","detail":"text is required"}"#.utf8)))
        #expect(!SupabaseAylaService.rejectsPlanFields(status: 500, body: rejected))
        let request = AylaRequest(text: "Hoi", device: .phone, input: .text, planId: "p", planStepId: "s")
        #expect(request.withoutPlan.planId == nil)
        #expect(request.withoutPlan.planStepId == nil)
        #expect(request.withoutPlan.text == "Hoi")
    }

    @Test func anEmptyPlanHasNoProgressAndIsNotFinished() {
        let plan = PavePlan(name: "Leeg")
        #expect(plan.progress == 0)
        #expect(!plan.isFinished)
        #expect(plan.currentStep == nil)
    }

    @Test func aChatIsAddedOnceAndLinkedToItsStep() {
        var plan = PavePlan(template: template, now: now)
        let step = plan.steps[1].id
        plan.attach(conversationID: "c1", title: "Eerste", stepID: step)
        plan.attach(conversationID: "c1", title: "Nieuwe titel")
        #expect(plan.conversations.count == 1)
        #expect(plan.conversations[0].title == "Nieuwe titel")
        #expect(plan.steps[1].conversationID == "c1")
        plan.detach(conversationID: "c1")
        #expect(plan.conversations.isEmpty)
        #expect(plan.steps[1].conversationID == nil)
    }

    @Test func kindsFromOtherFlowsSurviveSaving() throws {
        let plan = PavePlan(template: template, now: now)
        let data = try JSONEncoder().encode(plan)
        let back = try JSONDecoder().decode(PavePlan.self, from: data)
        #expect(back == plan)
        #expect(back.steps[2].kind.rawValue == "somethingNew")
    }

    @Test func namesAreTidiedUp() {
        #expect(PavePlan.cleanName("  Mijn   plan ") == "Mijn plan")
        #expect(PavePlan.cleanName("   ") == nil)
    }

    @Test func theLocalServiceKeepsChanges() async throws {
        let service = LocalPlanService(fileURL: nil, seed: [PavePlan(id: "a", name: "A")])
        try await service.save(PavePlan(id: "b", name: "B"))
        var a = PavePlan(id: "a", name: "A2")
        a.goal = "Doel"
        try await service.save(a)
        try await service.delete(id: "b")
        let plans = try await service.plans()
        #expect(plans.map(\.name) == ["A2"])
    }

    @Test func theLocalServiceWritesAFile() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "plans-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try await LocalPlanService(fileURL: url).save(PavePlan(template: template, name: "Bewaard"))
        let plans = try await LocalPlanService(fileURL: url, seed: [PavePlan(name: "Niet")]).plans()
        #expect(plans.map(\.name) == ["Bewaard"])
    }
}
