import Foundation

/// A plan: a personal workspace where someone works towards one goal, step by step, with Ayla. It keeps its steps,
/// how far along they are and the chats with Ayla that belong to it. A plan knows nothing about the flow that made it
/// (finding work, a training, a portfolio): that flow brings its own steps and kinds of steps.
public struct PavePlan: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// What the plan works towards, in the user's own words; may be empty.
    public var goal: String
    /// The template the plan started from, for its icon; nil for an empty plan or one made by another flow.
    public var templateID: String?
    public var steps: [PavePlanStep]
    /// The chats with Ayla in this plan, in the order they were added.
    public var conversations: [PavePlanConversation]
    public var createdAt: Date
    public var updatedAt: Date
    /// When the plan was finished: by "Voltooien", or by finishing its last step. Nil while it is still going.
    public var completedAt: Date?
    /// Free room for the flow that made the plan, such as the id of what it is about. The plan itself never reads it.
    public var metadata: [String: String]

    public init(
        id: String = PavePlan.newID(), name: String, goal: String = "", templateID: String? = nil, steps: [PavePlanStep] = [],
        conversations: [PavePlanConversation] = [], createdAt: Date = .now, updatedAt: Date = .now, metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.templateID = templateID
        self.steps = steps
        self.conversations = conversations
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        normalize()
    }

    /// A new plan from a template: the first step is the one to work on.
    public init(template: PavePlanTemplate, name: String? = nil, goal: String? = nil, id: String = PavePlan.newID(), now: Date = .now) {
        self.init(
            id: id,
            name: name ?? template.name,
            goal: goal ?? template.goal,
            templateID: template.steps.isEmpty ? nil : template.id,
            steps: template.steps.map { PavePlanStep(title: $0.title, summary: $0.summary, kind: $0.kind, metadata: $0.metadata) },
            createdAt: now,
            updatedAt: now,
            metadata: template.metadata
        )
    }

    /// Ids are UUIDs in lower case, as the database gives them back, so an id never changes after loading.
    public static func newID() -> String { UUID().uuidString.lowercased() }

    public static let maxNameLength = 80
    public static let maxGoalLength = 280

    /// A name someone typed, tidied up; nil when nothing is left.
    public static func cleanName(_ text: String) -> String? {
        let words = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !words.isEmpty else { return nil }
        return String(words.prefix(maxNameLength))
    }

    public static func cleanGoal(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxGoalLength))
    }

    // MARK: Progress

    /// Steps that count for the progress: a skipped step is left out everywhere, in the number of steps too, so
    /// "Stap 3 van 5", "2 van 5 afgerond" and the ring always agree.
    public var countedSteps: [PavePlanStep] { steps.filter { $0.status != .skipped } }

    public var doneCount: Int { countedSteps.count { $0.status == .done } }
    public var totalCount: Int { countedSteps.count }

    /// From 0 to 1; a plan without steps has made no progress yet.
    public var progress: Double {
        totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount)
    }

    /// Finished: marked so, or every step is done or skipped (and there is at least one).
    public var isFinished: Bool {
        completedAt != nil || (!steps.isEmpty && !hasStepsLeft)
    }

    private var hasStepsLeft: Bool { steps.contains { $0.status == .upcoming || $0.status == .active } }

    /// "Voltooien": every step still to do is done, and the plan is finished.
    public mutating func complete(at date: Date = .now) {
        for index in steps.indices where steps[index].status == .upcoming || steps[index].status == .active {
            steps[index].status = .done
            steps[index].completedAt = date
        }
        completedAt = date
        updatedAt = date
    }

    /// "Weer openen": the plan goes on, from the last step that was done.
    public mutating func reopen(at date: Date = .now) {
        completedAt = nil
        if !hasStepsLeft, let last = steps.lastIndex(where: { $0.status == .done }) {
            steps[last].status = .active
            steps[last].completedAt = nil
        }
        updatedAt = date
    }

    /// The step being worked on.
    public var currentStep: PavePlanStep? { steps.first { $0.status == .active } }

    /// The place of the current step among the steps that count, from 1; with every step done, the number of steps.
    public var currentNumber: Int {
        let counted = countedSteps
        if let index = counted.firstIndex(where: { $0.status == .active }) { return index + 1 }
        return counted.count
    }

    // MARK: Changing steps

    /// Changes a step's status and keeps the plan in order: one step at a time is active, and when it is done the
    /// next step that is still to come becomes active.
    public mutating func setStatus(_ status: PavePlanStep.Status, of stepID: String, at date: Date = .now) {
        guard let index = steps.firstIndex(where: { $0.id == stepID }), steps[index].status != status else { return }
        if status == .active {
            for other in steps.indices where steps[other].status == .active { steps[other].status = .upcoming }
        }
        steps[index].status = status
        steps[index].completedAt = status == .done ? date : nil
        updatedAt = date
        normalize()
    }

    /// Finishes the step being worked on; the next one becomes active.
    public mutating func completeCurrentStep(at date: Date = .now) {
        guard let current = currentStep else { return }
        setStatus(.done, of: current.id, at: date)
    }

    public mutating func addStep(_ step: PavePlanStep, at date: Date = .now) {
        var step = step
        if step.status == .active, currentStep != nil { step.status = .upcoming }
        steps.append(step)
        updatedAt = date
        normalize()
    }

    /// Adds a step right after the step you are on, where it belongs to what you are doing now; at the end without one.
    public mutating func addStepAfterCurrent(_ step: PavePlanStep, at date: Date = .now) {
        let next = currentStep.flatMap { current in steps.firstIndex { $0.id == current.id } }.map { $0 + 1 }
        addStep(step, at: date)
        guard let next, next < steps.count - 1 else { return }
        moveStep(id: step.id, before: steps[next].id, at: date)
    }

    /// Puts a step before another one, or at the end when `otherID` is nil. Which step is active stays the same.
    public mutating func moveStep(id: String, before otherID: String?, at date: Date = .now) {
        guard id != otherID, let from = steps.firstIndex(where: { $0.id == id }) else { return }
        let step = steps.remove(at: from)
        if let otherID, let to = steps.firstIndex(where: { $0.id == otherID }) {
            steps.insert(step, at: to)
        } else {
            steps.append(step)
        }
        updatedAt = date
        normalize()
    }

    public mutating func removeStep(id: String, at date: Date = .now) {
        steps.removeAll { $0.id == id }
        updatedAt = date
        normalize()
    }

    public mutating func updateStep(_ step: PavePlanStep, at date: Date = .now) {
        guard let index = steps.firstIndex(where: { $0.id == step.id }) else { return }
        let status = step.status
        var changed = step
        changed.status = steps[index].status
        steps[index] = changed
        updatedAt = date
        if status != changed.status { setStatus(status, of: step.id, at: date) }
    }

    /// One active step while anything is left to do, and it is the first one not done when none was chosen. A plan
    /// is finished when nothing is left, and goes on again when a step is reopened.
    public mutating func normalize() {
        let actives = steps.indices.filter { steps[$0].status == .active }
        for extra in actives.dropFirst() { steps[extra].status = .upcoming }
        if actives.isEmpty, let next = steps.firstIndex(where: { $0.status == .upcoming }) {
            steps[next].status = .active
        }
        if hasStepsLeft {
            completedAt = nil
        } else if !steps.isEmpty, completedAt == nil {
            completedAt = updatedAt
        }
    }

    // MARK: Chats

    public func contains(conversationID: String) -> Bool {
        conversations.contains { $0.id == conversationID }
    }

    /// Adds a chat to the plan, optionally for one step; a chat that is already in it only gets its title updated.
    public mutating func attach(conversationID: String, title: String = "", stepID: String? = nil, at date: Date = .now) {
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            if !title.isEmpty { conversations[index].title = title }
            if let stepID { conversations[index].stepID = stepID }
        } else {
            conversations.append(PavePlanConversation(id: conversationID, title: title, stepID: stepID, addedAt: date))
        }
        if let stepID, let index = steps.firstIndex(where: { $0.id == stepID }), steps[index].conversationID == nil {
            steps[index].conversationID = conversationID
        }
        updatedAt = date
    }

    public mutating func detach(conversationID: String, at date: Date = .now) {
        conversations.removeAll { $0.id == conversationID }
        for index in steps.indices where steps[index].conversationID == conversationID { steps[index].conversationID = nil }
        updatedAt = date
    }
}

/// One step in a plan.
public struct PavePlanStep: Codable, Equatable, Sendable, Identifiable {
    public enum Status: String, Codable, Sendable, CaseIterable {
        case upcoming
        case active
        case done
        case skipped
    }

    public var id: String
    public var title: String
    /// A short line about what the step is.
    public var summary: String
    public var kind: Kind
    public var status: Status
    /// The chat where this step was worked on, if any.
    public var conversationID: String?
    public var completedAt: Date?
    /// Free room for the flow the step belongs to.
    public var metadata: [String: String]

    public init(
        id: String = PavePlan.newID(), title: String, summary: String = "", kind: Kind = .general, status: Status = .upcoming,
        conversationID: String? = nil, completedAt: Date? = nil, metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.kind = kind
        self.status = status
        self.conversationID = conversationID
        self.completedAt = completedAt
        self.metadata = metadata
    }

    /// When the step should be done ("2026-12-15"), set by you or by Ayla; nil without a deadline.
    public static let dueKey = "due"
    /// The vault items that show this step is done, by id, comma-separated.
    public static let evidenceKey = "evidenceIDs"

    public var due: String? {
        get { metadata[Self.dueKey] }
        set { metadata[Self.dueKey] = newValue }
    }

    public var evidenceIDs: [String] {
        get { metadata[Self.evidenceKey]?.split(separator: ",").map(String.init) ?? [] }
        set { metadata[Self.evidenceKey] = newValue.isEmpty ? nil : newValue.joined(separator: ",") }
    }

    /// What sort of step it is. An open set: a flow can bring kinds of its own, and the app shows those as a general step.
    public struct Kind: AylaValue {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let general = Self(rawValue: "general")
        /// Talking something through with Ayla.
        public static let conversation = Self(rawValue: "conversation")
        /// Something to look into or learn.
        public static let research = Self(rawValue: "research")
        /// Adding evidence to the vault.
        public static let evidence = Self(rawValue: "evidence")
        /// Having evidence confirmed by someone else.
        public static let verification = Self(rawValue: "verification")
        /// A document to write or improve.
        public static let document = Self(rawValue: "document")
        /// Something to do outside PAVE.
        public static let action = Self(rawValue: "action")
        /// Looking back on what happened.
        public static let reflection = Self(rawValue: "reflection")
        /// A moment in time, such as a meeting or a deadline.
        public static let milestone = Self(rawValue: "milestone")
        /// Something to fill in or update in the profile.
        public static let profile = Self(rawValue: "profile")
        /// Getting in touch with someone, such as a mentor or an employer.
        public static let contact = Self(rawValue: "contact")
    }
}

/// A chat with Ayla that belongs to a plan. The title is kept so the plan can name the chat before the chats load.
public struct PavePlanConversation: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// The step the chat was started for, if any.
    public var stepID: String?
    public var addedAt: Date

    public init(id: String, title: String = "", stepID: String? = nil, addedAt: Date = .now) {
        self.id = id
        self.title = title
        self.stepID = stepID
        self.addedAt = addedAt
    }
}

/// The steps a plan starts with. A flow (finding work, a training) makes its own templates; the plan only follows them.
public struct PavePlanTemplate: Equatable, Sendable, Identifiable {
    public struct Step: Equatable, Sendable {
        public var title: String
        public var summary: String
        public var kind: PavePlanStep.Kind
        public var metadata: [String: String]

        public init(_ title: String, summary: String = "", kind: PavePlanStep.Kind = .general, metadata: [String: String] = [:]) {
            self.title = title
            self.summary = summary
            self.kind = kind
            self.metadata = metadata
        }
    }

    public var id: String
    public var name: String
    /// One line about what the template is for, in the list of templates.
    public var summary: String
    public var goal: String
    public var steps: [Step]
    public var metadata: [String: String]

    public init(id: String, name: String, summary: String = "", goal: String = "", steps: [Step], metadata: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.summary = summary
        self.goal = goal
        self.steps = steps
        self.metadata = metadata
    }

    /// A plan without steps yet.
    public static let empty = PavePlanTemplate(id: "empty", name: "", steps: [])
}
