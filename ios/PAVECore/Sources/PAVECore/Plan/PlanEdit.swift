import Foundation

public extension PavePlan {
    /// Ayla's proposed changes, as far as the user kept them: new steps where she put them, steps taken out, steps
    /// moved. A step that is gone meanwhile is left alone; a place after a step that is gone becomes the end.
    mutating func apply(_ changes: [AylaReply.PlanEdit.Change], at date: Date = .now) {
        for change in changes {
            switch change.op {
            case .add:
                guard !change.title.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let step = PavePlanStep(title: change.title, summary: change.why, kind: PavePlanStep.Kind(rawValue: change.kind ?? "general"))
                addStep(step, at: date)
                place(step.id, after: change.afterStepId, at: date)
            case .remove:
                guard let id = change.stepId, steps.contains(where: { $0.id == id && $0.status != .done }) else { continue }
                removeStep(id: id, at: date)
            case .move:
                guard let id = change.stepId, steps.contains(where: { $0.id == id }) else { continue }
                place(id, after: change.afterStepId, at: date)
            }
        }
    }

    private mutating func place(_ id: String, after afterID: String?, at date: Date) {
        let others = steps.filter { $0.id != id }
        if let afterID {
            guard let index = others.firstIndex(where: { $0.id == afterID }) else { return moveStep(id: id, before: nil, at: date) }
            moveStep(id: id, before: index + 1 < others.count ? others[index + 1].id : nil, at: date)
        } else {
            moveStep(id: id, before: others.first?.id, at: date)
        }
    }
}
