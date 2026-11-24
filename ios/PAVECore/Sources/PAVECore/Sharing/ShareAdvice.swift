import Foundation

/// What PAVE points out about the shares: one to take back now its application is over, one that ends soon, and a
/// report of who looked at what (like the Privacy Report of iOS).
public enum ShareAdvice {
    public struct Suggestion: Equatable, Sendable, Identifiable {
        public enum Reason: Equatable, Sendable {
            /// The application it was made for is rejected or got an offer.
            case applicationEnded(ApplicationStatus)
            /// The deadline of the application passed while it was still a concept.
            case deadlinePassed
            /// It ends within a day.
            case endsSoon
        }

        public var id: String { shareID }
        public let shareID: String
        public let reason: Reason
    }

    /// One suggestion per live share at most, the strongest reason first.
    public static func suggestions(shares: [ProfileShare], applications: [ApplicationDraft], now: Date = .now) -> [Suggestion] {
        shares.filter { $0.state(at: now) == .active || $0.state(at: now) == .paused }.compactMap { share in
            if let vacancyID = share.content.vacancyID, let application = applications.first(where: { $0.vacancy.id == vacancyID }) {
                let tracking = application.progress
                if tracking.status == .rejected || tracking.status == .offer {
                    return Suggestion(shareID: share.id, reason: .applicationEnded(tracking.status))
                }
                if tracking.status == .concept, let deadline = tracking.deadline, case .overdue = ApplicationDeadline.of(deadline, now: now) {
                    return Suggestion(shareID: share.id, reason: .deadlinePassed)
                }
            }
            if share.state(at: now) == .active, share.expiresAt.timeIntervalSince(now) < 86_400 {
                return Suggestion(shareID: share.id, reason: .endsSoon)
            }
            return nil
        }
    }

    public struct Report: Equatable, Sendable {
        /// Shares someone can look at now.
        public let active: Int
        public let paused: Int
        /// Looks and downloads in the period.
        public let looks: Int
        public let downloads: Int
        /// Per share with looks in the period, the most looked at first.
        public let byShare: [(shareID: String, looks: Int, lastLook: Date)]

        public static func == (a: Report, b: Report) -> Bool {
            a.active == b.active && a.paused == b.paused && a.looks == b.looks && a.downloads == b.downloads
                && a.byShare.map(\.shareID) == b.byShare.map(\.shareID) && a.byShare.map(\.looks) == b.byShare.map(\.looks)
        }
    }

    public static let reportDays = 30

    public static func report(_ shares: [ProfileShare], now: Date = .now) -> Report {
        let since = now.addingTimeInterval(-TimeInterval(reportDays) * 86_400)
        let inPeriod = shares.map { share in (share, share.looks.filter { $0.date >= since }) }
        let byShare = inPeriod
            .filter { !$0.1.isEmpty }
            .map { (shareID: $0.0.id, looks: $0.1.count, lastLook: $0.1.map(\.date).max() ?? since) }
            .sorted { ($0.looks, $0.lastLook) > ($1.looks, $1.lastLook) }
        let all = inPeriod.flatMap(\.1)
        return Report(
            active: shares.count { $0.state(at: now) == .active },
            paused: shares.count { $0.state(at: now) == .paused },
            looks: all.count { $0.action == .view },
            downloads: all.count { $0.action == .download },
            byShare: byShare
        )
    }

    /// Looks since the last time the owner was told, for a notification.
    public static func newLooks(in shares: [ProfileShare], since: Date) -> [(share: ProfileShare, look: ShareLook)] {
        shares.flatMap { share in share.looks.filter { $0.date > since }.map { (share, $0) } }.sorted { $0.look.date < $1.look.date }
    }
}
