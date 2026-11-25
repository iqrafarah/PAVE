import Foundation

/// The one thing to do next with your applications, for a glance at the wrist: a talk that is coming, an invitation at
/// the fair to answer, or a deadline. Only the company and when; never what you wrote.
public struct NextStep: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case talk, answer, deadline }

    public var kind: Kind
    public var company: String
    public var date: Date

    public init(kind: Kind, company: String, date: Date) {
        self.kind = kind
        self.company = company
        self.date = date
    }

    /// The soonest step; an invitation waiting for your answer goes first, as it waits for you.
    public static func pick(
        drafts: [ApplicationDraft], fair: [FairApplication], employerName: (String) -> String, now: Date = .now
    ) -> NextStep? {
        let toAnswer = fair.filter(\.awaitsAnswer).compactMap { application in
            application.invitedFor.map { NextStep(kind: .answer, company: employerName(application.employerSlug), date: $0) }
        }
        if let first = toAnswer.min(by: { $0.date < $1.date }) { return first }

        var steps: [NextStep] = []
        for draft in drafts {
            if let talk = draft.progress.invitation?.chosen, talk > now {
                steps.append(NextStep(kind: .talk, company: draft.vacancy.company, date: talk))
            }
            if draft.progress.status == .concept, let deadline = draft.progress.deadline, deadline > now {
                steps.append(NextStep(kind: .deadline, company: draft.vacancy.company, date: deadline))
            }
        }
        for application in fair where application.answer == .accepted {
            if let talk = application.invitedFor, talk > now {
                steps.append(NextStep(kind: .talk, company: employerName(application.employerSlug), date: talk))
            }
        }
        return steps.min { $0.date < $1.date }
    }
}
