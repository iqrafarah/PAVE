import Foundation

/// What Ayla gets to propose steps for a plan (the `ayla-plan` function): the plan's name and goal, the steps it
/// already has, the titles of the evidence she may see, and the vacancy the plan is about when there is one.
public struct PlanStepsRequest: Encodable, Equatable, Sendable {
    public struct Evidence: Encodable, Equatable, Sendable {
        public let title: String
        public let category: String
        public let verified: Bool
    }

    public struct Job: Encodable, Equatable, Sendable {
        public let title: String
        public let company: String
        public let summary: String?
        public let missing: [String]

        public init(title: String, company: String, summary: String?, missing: [String]) {
            self.title = title
            self.company = company
            self.summary = summary
            self.missing = missing
        }
    }

    public let name: String
    public let goal: String
    public let existing: [String]
    public let evidence: [Evidence]
    public let skills: [String]
    public let vacancy: Job?

    /// Only evidence with "Ayla mag dit bekijken en gebruiken" goes along, and of it only the title, the kind and
    /// whether it is verified: never a description or a file.
    public init(name: String, goal: String, existing: [String], items: [VaultItem], job: Job? = nil) {
        let allowed = items.filter { $0.aylaAllowedAt != nil && $0.archivedAt == nil && $0.status != .rejected }
        self.name = name
        self.goal = goal
        self.existing = existing
        evidence = allowed.prefix(60).map { Evidence(title: $0.title, category: $0.category.rawValue, verified: $0.status == .verified) }
        var seen = Set<String>()
        skills = Array(allowed.flatMap(\.skills).filter { seen.insert($0.lowercased()).inserted }.prefix(60))
        vacancy = job
    }

    /// How many pieces of evidence Ayla reads for this, to say before she starts.
    public var evidenceCount: Int { evidence.count }
}

/// Ayla's answer: steps to choose from. A kind the app does not know becomes a general step.
public struct PlanStepsProposal: Decodable, Equatable, Sendable {
    struct Step: Decodable, Equatable { let title: String; let summary: String?; let kind: String? }
    let steps: [Step]

    public var templateSteps: [PavePlanTemplate.Step] {
        steps.compactMap { step in
            guard let title = PavePlan.cleanName(step.title) else { return nil }
            return PavePlanTemplate.Step(title, summary: PavePlan.cleanGoal(step.summary ?? ""), kind: PavePlanStep.Kind(rawValue: step.kind ?? "general"))
        }
    }
}
