import Foundation

/// When you can work, for a side job: the days and how many hours a week at most. Kept for the next application.
public struct Availability: Codable, Equatable, Sendable {
    public enum Day: String, Codable, CaseIterable, Sendable {
        case maandag, dinsdag, woensdag, donderdag, vrijdag, zaterdag, zondag
    }

    public var days: [Day]
    public var maxHours: Int?

    public init(days: [Day] = [], maxHours: Int? = nil) {
        self.days = days
        self.maxHours = maxHours
    }

    public var isEmpty: Bool { days.isEmpty && maxHours == nil }
}

/// What you leave with one vacancy at the fair instead of a CV: who you are, why this job, when you can work, and what
/// you said in a short spoken pitch, written out.
public struct FairApplicationCard: Codable, Equatable, Sendable {
    public var name: String
    public var headline: String
    public var why: String
    public var pitch: String
    public var availability: Availability

    public init(name: String, headline: String = "", why: String = "", pitch: String = "", availability: Availability = Availability()) {
        self.name = name
        self.headline = headline
        self.why = why
        self.pitch = pitch
        self.availability = availability
    }

    public enum Problem: Equatable, Sendable { case noName, noWhy }

    public var problem: Problem? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return .noName }
        if why.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pitch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .noWhy }
        return nil
    }
}

/// An application left at the fair, and what the employer did with it.
public struct FairApplication: Identifiable, Equatable, Sendable {
    public enum Status: String, Sendable { case new, invited, declined }
    public enum Answer: String, Sendable { case accepted, declined }

    public let id: String
    public let employerSlug: String
    public let vacancyID: String
    public let vacancyTitle: String
    public let card: FairApplicationCard
    public var status: Status
    public var invitedFor: Date?
    public var invitationMessage: String?
    public var answer: Answer?
    public let createdAt: Date

    public init(
        id: String, employerSlug: String, vacancyID: String, vacancyTitle: String, card: FairApplicationCard, status: Status = .new,
        invitedFor: Date? = nil, invitationMessage: String? = nil, answer: Answer? = nil, createdAt: Date = .now
    ) {
        self.id = id
        self.employerSlug = employerSlug
        self.vacancyID = vacancyID
        self.vacancyTitle = vacancyTitle
        self.card = card
        self.status = status
        self.invitedFor = invitedFor
        self.invitationMessage = invitationMessage
        self.answer = answer
        self.createdAt = createdAt
    }

    /// Invited and not answered yet.
    public var awaitsAnswer: Bool { status == .invited && answer == nil }
}

/// One application as the employer sees it in the inbox.
public struct InboxApplication: Identifiable, Equatable, Sendable, Decodable {
    public struct Days: Equatable, Sendable, Decodable {
        public let days: [String]
        public let maxHours: Int?
    }
    public let id: String
    public let vacancyTitle: String
    public let name: String?
    public let headline: String?
    public let why: String?
    public let pitch: String?
    public let availability: Days
    public let status: String
    public let invitedFor: Date?
    public let answer: String?
    public let appliedAt: Date
}

public struct EmployerInbox: Equatable, Sendable {
    public let name: String
    public let stand: String?
    public let applications: [InboxApplication]
}
