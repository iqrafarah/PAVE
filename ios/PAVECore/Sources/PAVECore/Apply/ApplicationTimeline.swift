import Foundation

/// One moment in the life of an application: a status you set, a share, someone who looked, the invitation, the talk.
public struct ApplicationTimelineEvent: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case status(ApplicationStatus)
        case shared(recipient: String)
        case looked(by: String?, downloaded: Bool)
        case stoppedSharing(recipient: String)
        case invited
        case talk
        case deadline
    }

    public var id: String
    public var date: Date
    public var kind: Kind
    /// Still to come: the talk or the deadline.
    public var isAhead: Bool

    public init(id: String, date: Date, kind: Kind, isAhead: Bool = false) {
        self.id = id
        self.date = date
        self.kind = kind
        self.isAhead = isAhead
    }
}

/// Everything that happened with one application, from what you kept yourself and what the shares saw: what is ahead
/// first (the soonest on top), then what happened, newest first.
public enum ApplicationTimeline {
    public static func events(tracking: ApplicationTracking, shares: [ProfileShare], now: Date = .now) -> [ApplicationTimelineEvent] {
        var past: [ApplicationTimelineEvent] = []
        var ahead: [ApplicationTimelineEvent] = []

        for (index, change) in tracking.history.enumerated() {
            past.append(.init(id: "status-\(index)", date: change.date, kind: .status(change.status)))
        }
        for share in shares {
            past.append(.init(id: "shared-\(share.id)", date: share.createdAt, kind: .shared(recipient: share.recipient)))
            for look in share.looks {
                past.append(.init(id: "look-\(look.id)", date: look.date, kind: .looked(by: look.viewerName, downloaded: look.action == .download)))
            }
            if let revoked = share.revokedAt {
                past.append(.init(id: "stopped-\(share.id)", date: revoked, kind: .stoppedSharing(recipient: share.recipient)))
            }
        }
        if let invitation = tracking.invitation, invitation.hasArrived(now: now) {
            past.append(.init(id: "invited", date: invitation.arrivesAt, kind: .invited))
            if let talk = invitation.chosen {
                let event = ApplicationTimelineEvent(id: "talk", date: talk, kind: .talk, isAhead: talk > now)
                if event.isAhead { ahead.append(event) } else { past.append(event) }
            }
        }
        if tracking.status == .concept, let deadline = tracking.deadline, deadline > now {
            ahead.append(.init(id: "deadline", date: deadline, kind: .deadline, isAhead: true))
        }
        return ahead.sorted { $0.date < $1.date } + past.sorted { $0.date > $1.date }
    }
}
