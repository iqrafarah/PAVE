import Foundation

/// Something you just did in PAVE that can finish the step of a plan you are on: evidence in the vault, asking someone
/// to verify it, sending an application, or a practice talk with its report.
public enum PlanProgressEvent: Equatable, Sendable {
    case evidenceAdded(itemID: String?)
    case verificationRequested(itemID: String)
    case applicationSent(vacancyID: String)
    case practiceFinished(vacancyID: String)

    /// The evidence it was about, to keep with the step once it is done.
    public var itemID: String? {
        switch self {
        case .evidenceAdded(let id): id
        case .verificationRequested(let id): id
        case .applicationSent, .practiceFinished: nil
        }
    }

    public var vacancyID: String? {
        switch self {
        case .applicationSent(let id), .practiceFinished(let id): id
        case .evidenceAdded, .verificationRequested: nil
        }
    }
}

public extension PavePlan {
    /// The step you are on, when what you just did is what it asks for: evidence for an evidence step, a request for a
    /// verification step, a sent application for a document step, a practice talk for a talk. Nil otherwise, so a
    /// step is never offered as done on a guess.
    func stepFinished(by event: PlanProgressEvent) -> PavePlanStep? {
        guard !isFinished, let step = currentStep else { return nil }
        let fits = switch event {
        case .evidenceAdded: step.kind == .evidence
        case .verificationRequested: step.kind == .verification
        case .applicationSent: step.kind == .document
        case .practiceFinished: step.kind == .conversation
        }
        return fits ? step : nil
    }
}

public extension PavePlan {
    /// The step is done, with the evidence that shows it, when there is some.
    mutating func finishStep(id: String, evidenceID: String?, at date: Date = .now) {
        if let evidenceID, let index = steps.firstIndex(where: { $0.id == id }), !steps[index].evidenceIDs.contains(evidenceID) {
            steps[index].evidenceIDs.append(evidenceID)
        }
        setStatus(.done, of: id, at: date)
    }
}
