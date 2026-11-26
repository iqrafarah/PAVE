import Foundation

/// Which evidence goes on a CV for one vacancy, and why. Made on the device from what is known: the skills the vacancy
/// asks for (from Ayla's match), how long ago something was, and how much fits on one page. The user sees every choice
/// with its reason and can turn each one round.
public enum ApplicationProposal {
    public enum Reason: Equatable, Sendable {
        /// On: it has skills the vacancy asks for.
        case fits([String])
        /// On: it is still going.
        case current
        /// On: not long ago.
        case recent
        /// On: a diploma belongs on every CV.
        case education
        /// Off: long ago and nothing the vacancy asks for.
        case oldAndUnrelated
        /// Off: the least fitting, left out so the CV fits on one page.
        case forOnePage
    }

    public struct Choice: Equatable, Sendable {
        public var isOn: Bool
        public var reason: Reason

        public init(isOn: Bool, reason: Reason) {
            self.isOn = isOn
            self.reason = reason
        }
    }

    /// Longer ago than this counts as old.
    public static let oldAfterMonths = 48

    /// What is on and off before looking at the length, per entry made from the vault. Typed entries are left alone.
    public static func choices(for draft: ApplicationDraft, items: [VaultItem], today: VaultDay) -> [String: Choice] {
        let wanted = wantedSkills(draft.vacancy)
        var choices: [String: Choice] = [:]
        for section in draft.cv.sections {
            for entry in section.entries {
                guard let item = items.first(where: { $0.id == entry.sourceItemID }) else { continue }
                if section.kind == .education {
                    choices[entry.id] = Choice(isOn: true, reason: .education)
                    continue
                }
                let fitting = item.skills.filter { wanted.contains($0.lowercased()) }
                if !fitting.isEmpty {
                    choices[entry.id] = Choice(isOn: true, reason: .fits(Array(fitting.prefix(2))))
                } else if item.isCurrent {
                    choices[entry.id] = Choice(isOn: true, reason: .current)
                } else if monthsAgo(item, today: today) > oldAfterMonths {
                    choices[entry.id] = Choice(isOn: false, reason: .oldAndUnrelated)
                } else {
                    choices[entry.id] = Choice(isOn: true, reason: .recent)
                }
            }
        }
        return choices
    }

    /// The proposal for one page: the choices above, and when the CV is still longer than a page the least fitting
    /// entries are left out until it fits. `pages` says how many pages a draft takes in its design.
    public static func fitted(
        _ draft: ApplicationDraft, items: [VaultItem], today: VaultDay, pages: (ApplicationDraft) -> Int
    ) -> (draft: ApplicationDraft, choices: [String: Choice]) {
        var choices = choices(for: draft, items: items, today: today)
        var draft = draft
        apply(choices.mapValues(\.isOn), to: &draft)
        for id in trimmed(draft, items: items, today: today, pages: pages) {
            choices[id] = Choice(isOn: false, reason: .forOnePage)
        }
        apply(choices.mapValues(\.isOn), to: &draft)
        return (draft, choices)
    }

    /// The entries to leave out so the CV as it is now fits on one page: as few as possible, the least worth keeping
    /// first. Diplomas and the strongest piece of experience always stay. Empty when it fits already.
    public static func trimmed(_ draft: ApplicationDraft, items: [VaultItem], today: VaultDay, pages: (ApplicationDraft) -> Int) -> [String] {
        guard pages(draft) > 1 else { return [] }
        let order = trimOrder(draft, items: items, today: today)
        guard !order.isEmpty else { return [] }
        func without(_ count: Int) -> ApplicationDraft {
            var shorter = draft
            apply(Dictionary(uniqueKeysWithValues: order.prefix(count).map { ($0, false) }), to: &shorter)
            return shorter
        }
        // Leaving out more never makes it longer, so the smallest number that fits is found by halving.
        var low = 1
        var high = order.count
        while low < high {
            let middle = (low + high) / 2
            if pages(without(middle)) <= 1 { high = middle } else { low = middle + 1 }
        }
        return Array(order.prefix(low))
    }

    /// The visible entries that may be left out, the least worth keeping first.
    static func trimOrder(_ draft: ApplicationDraft, items: [VaultItem], today: VaultDay) -> [String] {
        let wanted = wantedSkills(draft.vacancy)
        var scored: [(id: String, score: Int, kind: CVSection.Kind)] = []
        for section in draft.cv.sections where section.isVisible && section.kind != .education {
            for entry in section.entries where entry.isVisible {
                let item = items.first { $0.id == entry.sourceItemID }
                let fitting = item?.skills.filter { wanted.contains($0.lowercased()) }.count ?? 0
                let years = item.map { monthsAgo($0, today: today) / 12 } ?? 0
                let kind = switch section.kind {
                case .experience: 4
                case .certificates: 2
                default: 1
                }
                let trusted = item?.status == .verified
                let score = fitting * 12 + (item?.isCurrent == true ? 6 : 0) + max(0, 5 - years) + kind + (trusted ? 1 : 0)
                scored.append((entry.id, score, section.kind))
            }
        }
        let strongest = scored.filter { $0.kind == .experience }.max { $0.score < $1.score }?.id
        return scored.filter { $0.id != strongest }.sorted { $0.score < $1.score }.map(\.id)
    }

    /// Turns entries on or off; the ones not named stay as they are.
    public static func apply(_ visible: [String: Bool], to draft: inout ApplicationDraft) {
        for section in draft.cv.sections.indices {
            for entry in draft.cv.sections[section].entries.indices {
                if let isOn = visible[draft.cv.sections[section].entries[entry].id] {
                    draft.cv.sections[section].entries[entry].isVisible = isOn
                }
            }
        }
    }

    /// The skills the vacancy names, lowercased: what the user has of them and what is still missing.
    static func wantedSkills(_ vacancy: Vacancy) -> Set<String> {
        Set((vacancy.matches + vacancy.skillGap).map { $0.skill.lowercased() })
    }

    /// How long ago it ended or was received; nothing for what is still going or has no date.
    static func monthsAgo(_ item: VaultItem, today: VaultDay) -> Int {
        guard !item.isCurrent, let day = item.endDate ?? item.issuedOn ?? item.startDate else { return 0 }
        return max(0, (today.year - day.year) * 12 + today.month - day.month)
    }
}
