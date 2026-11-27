import Foundation

/// How close a deadline is, in whole days.
public enum ApplicationDeadline: Equatable, Sendable {
    case overdue(days: Int)
    case today
    case upcoming(days: Int)

    public static func of(_ deadline: Date, now: Date, calendar: Calendar = .current) -> ApplicationDeadline {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: deadline)).day ?? 0
        if days < 0 { return .overdue(days: -days) }
        return days == 0 ? .today : .upcoming(days: days)
    }
}

/// One notification to plan.
public struct ApplicationReminder: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case deadlineTomorrow, deadlineToday, followUp, invitation
    }

    public var id: String { "application.\(vacancyID).\(kind.rawValue)" }
    public let vacancyID: String
    public let kind: Kind
    public let date: Date
    public let vacancyTitle: String
    public let company: String
}

/// Which notifications to plan for the applications that asked for them: the day before the deadline and on it for one
/// that is still a concept, and a week after "Verstuurd" to ask whether there is news. Nothing for what is done.
public enum ApplicationReminders {
    public static let followUpDays = 7
    /// iOS keeps 64 notifications per app.
    public static let maximum = 40

    public static func plan(_ drafts: [ApplicationDraft], now: Date, calendar: Calendar = .current) -> [ApplicationReminder] {
        var found: [ApplicationReminder] = []
        func add(_ draft: ApplicationDraft, _ kind: ApplicationReminder.Kind, day: Date, hour: Int) {
            guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), date > now else { return }
            found.append(ApplicationReminder(vacancyID: draft.vacancy.id, kind: kind, date: date, vacancyTitle: draft.vacancy.title, company: draft.vacancy.company))
        }
        // The demo's invitation is a message, not a reminder: it is announced also when reminders are off.
        for draft in drafts {
            if let invitation = draft.progress.invitation, invitation.chosen == nil, invitation.arrivesAt > now {
                found.append(ApplicationReminder(vacancyID: draft.vacancy.id, kind: .invitation, date: invitation.arrivesAt, vacancyTitle: draft.vacancy.title, company: draft.vacancy.company))
            }
        }
        for draft in drafts where draft.progress.remindsMe {
            let tracking = draft.progress
            if tracking.status == .concept, let deadline = tracking.deadline {
                let day = calendar.startOfDay(for: deadline)
                if let before = calendar.date(byAdding: .day, value: -1, to: day) { add(draft, .deadlineTomorrow, day: before, hour: 9) }
                add(draft, .deadlineToday, day: day, hour: 9)
            }
            if tracking.status == .sent, let changed = tracking.changedAt,
               let due = calendar.date(byAdding: .day, value: followUpDays, to: calendar.startOfDay(for: changed)) {
                add(draft, .followUp, day: due, hour: 10)
            }
        }
        return Array(found.sorted { $0.date < $1.date }.prefix(maximum))
    }
}
