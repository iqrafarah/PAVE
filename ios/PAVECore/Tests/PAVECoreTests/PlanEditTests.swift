import Foundation
import Testing
@testable import PAVECore

struct PlanEditTests {
    private var plan: PavePlan {
        var plan = PavePlan(name: "Piloot worden", steps: [
            PavePlanStep(id: "a", title: "Opleidingen vergelijken", kind: .research),
            PavePlanStep(id: "b", title: "Cursus Engels"),
            PavePlanStep(id: "c", title: "Aanmelden"),
        ])
        plan.normalize()
        return plan
    }

    @Test func keptChangesLandWhereAylaPutThem() throws {
        var plan = plan
        plan.apply([
            .init(op: .add, title: "Medische keuring aanvragen", kind: "action", afterStepId: "a", why: "De opleiding vraagt hem."),
            .init(op: .remove, stepId: "b", title: "Cursus Engels"),
            .init(op: .move, stepId: "c", title: "Aanmelden", afterStepId: nil),
            .init(op: .add, title: "Open dag bezoeken", afterStepId: "weg"),
        ])
        #expect(plan.steps.map(\.title) == ["Aanmelden", "Opleidingen vergelijken", "Medische keuring aanvragen", "Open dag bezoeken"])
        let keuring = try #require(plan.steps.first { $0.title.hasPrefix("Medische") })
        #expect(keuring.kind == .action)
        #expect(keuring.summary == "De opleiding vraagt hem.")
        #expect(plan.steps.filter { $0.status == .active }.count == 1)
    }

    @Test func aDoneStepIsNeverTakenOut() {
        var plan = plan
        plan.setStatus(.done, of: "a")
        plan.apply([.init(op: .remove, stepId: "a", title: "Opleidingen vergelijken")])
        #expect(plan.steps.count == 3)
    }

    @Test func aReplyWithAPlanEditDecodes() throws {
        let json = #"{"version":1,"id":"r","conversationId":"c","text":"Ik stel iets voor.","blocks":[],"usedData":[],"planEdit":{"id":"e","planId":"p","changes":[{"op":"add","title":"Keuring","kind":"action","afterStepId":null,"why":"Moet."},{"op":"remove","stepId":"s","title":"Engels","why":""}]}}"#
        let reply = try AylaReply.decode(Data(json.utf8))
        #expect(reply.planEdit?.changes.count == 2)
        #expect(reply.planEdit?.changes.first?.afterStepId == nil)
        #expect(reply.planEdit?.changes.last?.op == .remove)
    }
}
