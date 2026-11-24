import Foundation

/// Where an application stands, as the user says it does. PAVE sends nothing to an employer, so this is kept by hand.
public enum ApplicationStatus: String, Codable, CaseIterable, Sendable {
    case concept, sent, interview, offer, rejected

    public init(from decoder: any Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .concept
    }
}

/// What the user keeps about an application next to its CV and letter: the status and when it changed, a deadline, a
/// note, and whether PAVE may remind them.
public struct ApplicationTracking: Codable, Equatable, Sendable {
    public struct Change: Codable, Equatable, Sendable {
        public var status: ApplicationStatus
        public var date: Date

        public init(status: ApplicationStatus, date: Date) {
            self.status = status
            self.date = date
        }
    }

    public var status = ApplicationStatus.concept
    public var deadline: Date?
    public var note = ""
    /// When the status was last set.
    public var changedAt: Date?
    /// Every time the status was set, oldest first.
    public var history: [Change] = []
    /// A notification the day before the deadline and a week after "Verstuurd". Off until the user turns it on.
    public var remindsMe = false

    public init(status: ApplicationStatus = .concept, deadline: Date? = nil, note: String = "", changedAt: Date? = nil, history: [Change] = [], remindsMe: Bool = false) {
        self.status = status
        self.deadline = deadline
        self.note = note
        self.changedAt = changedAt
        self.history = history
        self.remindsMe = remindsMe
    }

    // Every key may be missing: what was kept by an earlier version has fewer.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        status = try values.decodeIfPresent(ApplicationStatus.self, forKey: .status) ?? .concept
        deadline = try values.decodeIfPresent(Date.self, forKey: .deadline)
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        changedAt = try values.decodeIfPresent(Date.self, forKey: .changedAt)
        history = try values.decodeIfPresent([Change].self, forKey: .history) ?? []
        remindsMe = try values.decodeIfPresent(Bool.self, forKey: .remindsMe) ?? false
    }

    /// Sets the status and keeps when; the same status again changes nothing.
    public mutating func set(_ new: ApplicationStatus, at date: Date = .now) {
        guard new != status else { return }
        status = new
        changedAt = date
        history.append(Change(status: new, date: date))
    }
}
