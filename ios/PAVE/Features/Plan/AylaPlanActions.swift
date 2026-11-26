import PAVECore
import SwiftUI

/// What Ayla does with plans when you ask her in a chat: open one, add a step, tick one off, remove one, put a plan in
/// a project, or make a plan for a vacancy. Names are your own words; the plan or step is looked up, and when nothing
/// or more than one thing fits she says so instead of guessing.
@MainActor
struct AylaPlanActions {
    let plans: PlanModel
    /// The plan this chat belongs to, which "het plan" means when no name is given.
    let chatPlan: PavePlan?

    func plan(named name: String?) -> PavePlan? {
        guard let name, !name.isEmpty else { return chatPlan ?? (plans.plans.count == 1 ? plans.plans.first : nil) }
        let named = plans.plans.map { AylaAppCommand.Named(id: $0.id, name: $0.name) }
        return AylaAppAction.best(name, in: named).flatMap { found in plans.plans.first { $0.id == found.id } }
    }

    /// A step by its title: in the plan of this chat first, then in any plan that is still going.
    func step(titled title: String?) -> (plan: PavePlan, step: PavePlanStep)? {
        let candidates = ([chatPlan].compactMap { $0 } + plans.plans.filter { $0.id != chatPlan?.id && !$0.isFinished })
        for plan in candidates {
            let named = plan.steps.map { AylaAppCommand.Named(id: $0.id, name: $0.title) }
            if let found = AylaAppAction.best(title, in: named), let step = plan.steps.first(where: { $0.id == found.id }) {
                return (plan, step)
            }
        }
        return nil
    }

    /// Nil when it worked; otherwise what to tell the user.
    func addStep(_ title: String?, toPlanNamed name: String?) -> String? {
        guard let title = title.flatMap(PavePlan.cleanName) else { return AylaMessages.actionUnknownValue }
        guard let plan = plan(named: name) else { return AylaMessages.actionNoPlan(name) }
        if plan.steps.contains(where: { $0.title.caseInsensitiveCompare(title) == .orderedSame }) { return AylaMessages.actionStepExists(title) }
        plans.addStep(PavePlanStep(title: title), to: plan.id)
        return nil
    }

    func markStep(_ title: String?, as value: String?) -> String? {
        let words: [String: PavePlanStep.Status] = [
            "done": .done, "klaar": .done, "afgerond": .done, "active": .active, "bezig": .active,
            "skipped": .skipped, "overgeslagen": .skipped, "upcoming": .upcoming,
        ]
        guard let status = words[value?.lowercased() ?? ""] else { return AylaMessages.actionUnknownValue }
        guard let found = step(titled: title) else { return AylaMessages.actionNoStep(title ?? "") }
        plans.setStatus(status, of: found.step.id, in: found.plan.id)
        return nil
    }

    /// A new title, or a new line about the step; nil when it worked, else what to tell the user.
    func editStep(_ title: String?, newTitle: String? = nil, summary: String? = nil) -> String? {
        guard let found = step(titled: title) else { return AylaMessages.actionNoStep(title ?? "") }
        var step = found.step
        if let newTitle {
            guard let clean = PavePlan.cleanName(newTitle) else { return AylaMessages.actionUnknownValue }
            step.title = clean
        }
        if let summary { step.summary = PavePlan.cleanGoal(summary) }
        plans.updateStep(step, in: found.plan.id)
        return nil
    }

    func removeStep(_ title: String?) -> String? {
        guard let found = step(titled: title) else { return AylaMessages.actionNoStep(title ?? "") }
        plans.removeStep(found.step.id, from: found.plan.id)
        return nil
    }

    /// Puts the plan in the project, or takes it out for "none". Its chats so far move along, so the project shows
    /// everything of the plan.
    func link(planNamed name: String?, toProjectNamed projectName: String?, projects: [AylaProject], moveChats: (PavePlan, AylaProject?) -> Void) -> String? {
        guard let plan = plan(named: name) else { return AylaMessages.actionNoPlan(name) }
        let none = ["none", "geen", "geen project", ""].contains(projectName?.lowercased() ?? "")
        if none {
            plans.setProject(nil, of: plan.id)
            return nil
        }
        let named = projects.map { AylaAppCommand.Named(id: $0.id, name: $0.name) }
        guard let found = AylaAppAction.best(projectName, in: named), let project = projects.first(where: { $0.id == found.id }) else {
            return AylaMessages.actionNoProject(projectName ?? "")
        }
        plans.setProject(project.id, of: plan.id)
        moveChats(plan, project)
        return nil
    }

    /// The invitations from the fair as one line each for Ayla: who, for what, when, and whether you answered.
    static func invitationLines(_ applications: [FairApplication]) -> [String] {
        applications.filter { $0.status == .invited }.prefix(6).map { application in
            let moment = application.invitedFor.map { ", \(ApplyMessages.slot($0))" } ?? ""
            let answer = switch application.answer {
            case .accepted?: "je komt"
            case .declined?: "je kunt niet"
            case nil: "wacht op je antwoord"
            }
            return String("\(FairApplicationDetail.employerName(application)): \(application.vacancyTitle)\(moment), \(answer)".prefix(200))
        }
    }

    /// An invitation by the employer's name or the job, among the ones still waiting or said yes to.
    static func invitation(_ name: String?, in applications: [FairApplication]) -> FairApplication? {
        let invited = applications.filter { $0.status == .invited }
        if invited.count == 1, name?.isEmpty != false { return invited[0] }
        let named = invited.map { AylaAppCommand.Named(id: $0.id, name: "\(FairApplicationDetail.employerName($0)) \($0.vacancyTitle)") }
        return AylaAppAction.best(name, in: named).flatMap { found in invited.first { $0.id == found.id } }
    }

    /// The plans as one line each for Ayla: the name, how far it is and the step you are on. No goals and no summaries.
    static func lines(_ plans: [PavePlan]) -> [String] {
        plans.filter { !$0.isFinished }.prefix(8).map { plan in
            let current = plan.currentStep.map { ", nu: \($0.title)" } ?? ""
            return String("\(plan.name) (\(plan.doneCount) van \(plan.totalCount) stappen\(current))".prefix(200))
        }
    }
}
