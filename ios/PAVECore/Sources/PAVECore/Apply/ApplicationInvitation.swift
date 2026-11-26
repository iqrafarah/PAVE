import Foundation

/// The demo's next step after applying: a few minutes after "Verstuurd", the company invites you for a first talk
/// ("kennismaking") and offers three moments. Nothing comes from a real employer; it is shown as a demo everywhere.
public struct ApplicationInvitation: Codable, Equatable, Sendable {
    public enum PrepStep: String, Codable, CaseIterable, Sendable {
        case rereadVacancy, readAboutCompany, practise, questions, route
    }

    public var arrivesAt: Date
    public var slots: [Date]
    public var chosen: Date?
    public var isRead = false
    public var done: Set<PrepStep> = []

    public init(arrivesAt: Date, slots: [Date], chosen: Date? = nil, isRead: Bool = false, done: Set<PrepStep> = []) {
        self.arrivesAt = arrivesAt
        self.slots = slots
        self.chosen = chosen
        self.isRead = isRead
        self.done = done
    }

    public static let delay: TimeInterval = 3 * 60
    public static let talkMinutes = 45

    /// Arrives a few minutes after sending, with three moments on the next working days from two days later: 10:00,
    /// 14:00 and 11:00.
    public static func after(sentAt: Date, calendar: Calendar = .current) -> ApplicationInvitation {
        let arrives = sentAt.addingTimeInterval(delay)
        var slots: [Date] = []
        var day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 2, to: arrives) ?? arrives)
        let hours = [10, 14, 11]
        while slots.count < hours.count {
            if !calendar.isDateInWeekend(day), let slot = calendar.date(bySettingHour: hours[slots.count], minute: 0, second: 0, of: day) {
                slots.append(slot)
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        }
        return ApplicationInvitation(arrivesAt: arrives, slots: slots)
    }

    public func hasArrived(now: Date = .now) -> Bool { now >= arrivesAt }
}

extension ApplicationTracking {
    /// Sets "Verstuurd" and, the first time, plans the demo invitation.
    public mutating func send(at date: Date = .now, calendar: Calendar = .current) {
        set(.sent, at: date)
        if invitation == nil { invitation = .after(sentAt: date, calendar: calendar) }
    }

    /// Picks a moment of the invitation; the application then stands at "Gesprek".
    public mutating func choose(_ slot: Date, at date: Date = .now) {
        guard var invitation, invitation.slots.contains(slot) else { return }
        invitation.chosen = slot
        invitation.isRead = true
        self.invitation = invitation
        set(.interview, at: date)
    }
}
