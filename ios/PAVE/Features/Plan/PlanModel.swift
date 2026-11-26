import Foundation
import Observation
import PAVECore

/// The user's plans, shared by the Plan screen and the Dynamic Bar in the chat. Every change shows at once and is
/// saved right after; when saving fails the change is undone and `problem` says so.
///
/// Other flows (such as finding work) use the same calls: `create(from:)` with their own template, `setStatus` when a
/// step is done, and `attach` for a chat that belongs to the plan.
@Observable
final class PlanModel {
    private(set) var plans: [PavePlan] = [] {
        // The plan on the Lock Screen follows every change, once the plans have loaded.
        didSet { if hasLoaded { liveActivity?.sync(plans) } }
    }
    private(set) var hasLoaded = false
    /// False until the plans exist in Supabase (migration 20261125130000); the Plan screen then says so.
    private(set) var isAvailable = true
    var problem: String?
    /// The plan open on the Plan screen; set from elsewhere ("Open plan" in the Dynamic Bar) to open it there.
    var openPlanID: String?

    private let service: (any PlanService)?
    /// The plan followed on the Lock Screen and in the Dynamic Island; nil in tests and previews.
    let liveActivity: PlanActivityController?

    init(service: (any PlanService)?, liveActivity: PlanActivityController? = nil) {
        self.service = service
        self.liveActivity = liveActivity
    }

    // MARK: Lock Screen

    var canFollow: Bool { liveActivity?.isAvailable == true }

    func isFollowed(_ planID: String) -> Bool { liveActivity?.followedPlanID == planID }

    var followedPlanID: String? { liveActivity?.followedPlanID }

    func follow(_ planID: String) {
        guard let plan = plan(id: planID) else { return }
        liveActivity?.follow(plan)
    }

    func stopFollowing() {
        liveActivity?.stop()
    }

    /// After "Naam en stap tonen" changed.
    func refreshLiveActivity() {
        liveActivity?.sync(plans, force: true)
    }

    /// The most recently changed first.
    var orderedPlans: [PavePlan] {
        plans.sorted { $0.updatedAt > $1.updatedAt }
    }

    func plan(id: String?) -> PavePlan? {
        guard let id else { return nil }
        return plans.first { $0.id == id }
    }

    func plan(containing conversationID: String?) -> PavePlan? {
        guard let conversationID else { return nil }
        return plans.first { $0.contains(conversationID: conversationID) }
    }

    /// The plan of the chat that is open, or of the new chat that is about to start in a plan.
    func activePlan(conversationID: String?, newChatPlanID: String?) -> PavePlan? {
        if let conversationID { return plan(containing: conversationID) }
        return plan(id: newChatPlanID)
    }

    func load() async {
        await fetch(quietly: false)
    }

    /// Loads the plans again, such as after Ayla changed a step; a failure leaves what is shown as it is.
    func refresh() async {
        await fetch(quietly: true)
    }

    private func fetch(quietly: Bool) async {
        defer { hasLoaded = true }
        guard let service else { return }
        do {
            plans = try await service.plans()
            isAvailable = true
            if !hasLoaded { liveActivity?.sync(plans) }
        } catch PlanServiceError.notSetUp {
            isAvailable = false
        } catch {
            if !quietly { problem = PlanMessages.loadFailed }
        }
    }

    /// A step Ayla changed in the chat. The server saved it already, so it only shows here, at once.
    func apply(_ update: AylaReply.PlanStepUpdate) {
        guard let index = plans.firstIndex(where: { $0.id == update.planId }) else { return }
        plans[index].setStatus(update.status, of: update.stepId)
    }

    // MARK: Plans

    @discardableResult
    func create(name: String, goal: String = "", from template: PavePlanTemplate = .empty) async -> PavePlan? {
        guard let name = PavePlan.cleanName(name) else { return nil }
        let plan = PavePlan(template: template, name: name, goal: PavePlan.cleanGoal(goal))
        plans.append(plan)
        guard await persist(plan) else {
            plans.removeAll { $0.id == plan.id }
            return nil
        }
        return plan
    }

    /// The plan Ayla made because the user asked for one in a chat, with that chat in it. Once per answer: the plan
    /// keeps the id of Ayla's proposal, so opening the chat again never makes it a second time.
    @discardableResult
    func create(from action: AylaReply.ProposedAction, conversationID: String?, title: String = "") async -> PavePlan? {
        guard let made = action.newPlan, !madeFromAyla.contains(action.id),
              !plans.contains(where: { $0.metadata[Self.aylaProposalKey] == action.id }) else { return nil }
        guard let name = PavePlan.cleanName(made.name) else { return nil }
        madeFromAyla.insert(action.id)
        defer { madeFromAyla.remove(action.id) }
        var template = made.template
        template.metadata[Self.aylaProposalKey] = action.id
        var plan = PavePlan(template: template, name: name, goal: PavePlan.cleanGoal(made.goal))
        // A chat belongs to one plan: asked for a new plan in a plan's chat, the chat moves to the new one.
        let old = self.plan(containing: conversationID)
        if let conversationID { plan.attach(conversationID: conversationID, title: title, at: plan.createdAt) }
        plans.append(plan)
        guard await persist(plan) else {
            plans.removeAll { $0.id == plan.id }
            return nil
        }
        if let old, let conversationID { detach(conversationID: conversationID, from: old.id) }
        return plan
    }

    private static let aylaProposalKey = "aylaProposal"
    /// Proposals being saved as a plan right now.
    private var madeFromAyla: Set<String> = []

    func rename(_ planID: String, to name: String, goal: String? = nil) async -> Bool {
        guard let name = PavePlan.cleanName(name) else { return false }
        return await change(planID) { plan in
            plan.name = name
            if let goal { plan.goal = PavePlan.cleanGoal(goal) }
            plan.updatedAt = .now
        }
    }

    func delete(_ planID: String) async {
        guard let index = plans.firstIndex(where: { $0.id == planID }) else { return }
        let removed = plans.remove(at: index)
        if openPlanID == planID { openPlanID = nil }
        do {
            try await service?.delete(id: planID)
        } catch {
            plans.insert(removed, at: min(index, plans.count))
            problem = PlanMessages.saveFailed
        }
    }

    /// "Voltooien": every step still to do is done, and the plan moves to Voltooid.
    func complete(_ planID: String) {
        Task { await change(planID) { $0.complete() } }
    }

    /// "Weer openen": the plan goes on from its last step.
    func reopen(_ planID: String) {
        Task { await change(planID) { $0.reopen() } }
    }

    /// Plans still going, the most recently changed first.
    var activePlans: [PavePlan] { orderedPlans.filter { !$0.isFinished } }

    /// Finished plans, the most recently finished first.
    var finishedPlans: [PavePlan] {
        plans.filter(\.isFinished).sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    // MARK: Steps

    func setStatus(_ status: PavePlanStep.Status, of stepID: String, in planID: String) {
        Task { await change(planID) { $0.setStatus(status, of: stepID) } }
    }

    func completeCurrentStep(in planID: String) {
        Task { await change(planID) { $0.completeCurrentStep() } }
    }

    func addStep(_ step: PavePlanStep, to planID: String) {
        Task { await change(planID) { $0.addStep(step) } }
    }

    /// Puts the plan in a project of Ayla, or takes it out (nil).
    func setProject(_ projectID: String?, of planID: String) {
        Task {
            await change(planID) { plan in
                plan.projectID = projectID
                plan.updatedAt = .now
            }
        }
    }

    /// Several steps at once, in order: the ones picked from Ayla's proposal.
    func addSteps(_ steps: [PavePlanTemplate.Step], to planID: String) {
        guard !steps.isEmpty else { return }
        Task {
            await change(planID) { plan in
                for step in steps { plan.addStep(PavePlanStep(title: step.title, summary: step.summary, kind: step.kind, metadata: step.metadata)) }
            }
        }
    }

    /// The plan whose page should open Ayla's proposal for steps at once: a plan just made "with Ayla".
    var proposesStepsFor: String?

    func updateStep(_ step: PavePlanStep, in planID: String) {
        Task { await change(planID) { $0.updateStep(step) } }
    }

    func removeStep(_ stepID: String, from planID: String) {
        Task { await change(planID) { $0.removeStep(id: stepID) } }
    }

    // MARK: Chats

    /// A chat belongs to the plan from now on; with a step, it is the chat for that step.
    func attach(conversationID: String, title: String = "", stepID: String? = nil, to planID: String) {
        Task { await change(planID) { $0.attach(conversationID: conversationID, title: title, stepID: stepID) } }
    }

    func detach(conversationID: String, from planID: String) {
        Task { await change(planID) { $0.detach(conversationID: conversationID) } }
    }

    /// Keeps the titles of the chats in the plans the same as in the list of chats. A chat that is not in the list is
    /// left alone: it may be new and not loaded yet. The screens hide chats that were deleted.
    func follow(_ list: AylaConversationList) {
        let titles = Dictionary(list.conversations.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        for plan in plans {
            var changed = plan
            for chat in plan.conversations {
                if let title = titles[chat.id], !title.isEmpty, title != chat.title {
                    changed.attach(conversationID: chat.id, title: title, at: plan.updatedAt)
                }
            }
            if changed != plan { Task { await change(plan.id) { $0 = changed } } }
        }
    }

    // MARK: Saving

    @discardableResult
    private func change(_ planID: String, _ edit: (inout PavePlan) -> Void) async -> Bool {
        guard let index = plans.firstIndex(where: { $0.id == planID }) else { return false }
        let before = plans[index]
        var plan = before
        edit(&plan)
        guard plan != before else { return true }
        plans[index] = plan
        guard await persist(plan) else {
            if let index = plans.firstIndex(where: { $0.id == planID }) { plans[index] = before }
            return false
        }
        return true
    }

    private func persist(_ plan: PavePlan) async -> Bool {
        guard let service else { return true }
        do {
            try await service.save(plan)
            return true
        } catch PlanServiceError.notSetUp {
            isAvailable = false
            problem = PlanMessages.notAvailable
            return false
        } catch {
            problem = PlanMessages.saveFailed
            return false
        }
    }
}
