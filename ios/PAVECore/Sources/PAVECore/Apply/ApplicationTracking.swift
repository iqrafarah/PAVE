import Foundation

/// Where an application stands, as the user says it does. PAVE sends nothing to an employer, so this is kept by hand.
public enum ApplicationStatus: String, Codable, CaseIterable, Sendable {
    case concept, sent, interview, offer, rejected

    public init(from decoder: any Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .concept
    }
}

/// What the user keeps about an application next to its CV and letter: the status, a deadline and a note.
public struct ApplicationTracking: Codable, Equatable, Sendable {
    public var status = ApplicationStatus.concept
    public var deadline: Date?
    public var note = ""
    /// When the status was last set.
    public var changedAt: Date?

    public init(status: ApplicationStatus = .concept, deadline: Date? = nil, note: String = "", changedAt: Date? = nil) {
        self.status = status
        self.deadline = deadline
        self.note = note
        self.changedAt = changedAt
    }
}
