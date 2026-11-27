import Foundation

/// "Wie keek er": every look at what you shared, newest first and grouped per day, with what that share showed.
/// Taken-back shares keep no looks (their content is wiped), so only what is or was live shows.
public enum ShareTimeline {
    public struct Entry: Identifiable, Equatable, Sendable {
        public var id: String { look.id }
        public let look: ShareLook
        public let share: ProfileShare

        /// Who it was: what the visitor said about themselves, else the person you shared with.
        public var who: String {
            let said = [look.viewerName, look.viewerOrganisation].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return said.isEmpty ? share.recipient : said.joined(separator: ", ")
        }

        /// Whether the visitor gave a name other than the person you shared with: worth pointing out.
        public var namedThemselves: Bool {
            guard let name = look.viewerName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return false }
            return name.localizedCaseInsensitiveCompare(share.recipientName) != .orderedSame
        }
    }

    public struct Day: Identifiable, Equatable, Sendable {
        public var id: Date { start }
        public let start: Date
        public let entries: [Entry]
    }

    public static func entries(_ shares: [ProfileShare], since: Date? = nil) -> [Entry] {
        shares.flatMap { share in share.looks.map { Entry(look: $0, share: share) } }
            .filter { since == nil || $0.look.date >= since! }
            .sorted { $0.look.date > $1.look.date }
    }

    public static func days(_ shares: [ProfileShare], since: Date? = nil, calendar: Calendar = .current) -> [Day] {
        let all = entries(shares, since: since)
        var days: [Day] = []
        for entry in all {
            let start = calendar.startOfDay(for: entry.look.date)
            if let last = days.last, last.start == start {
                days[days.count - 1] = Day(start: start, entries: last.entries + [entry])
            } else {
                days.append(Day(start: start, entries: [entry]))
            }
        }
        return days
    }
}
