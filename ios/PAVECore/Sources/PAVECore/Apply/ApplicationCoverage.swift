import Foundation

/// What the vacancy asks for, set against the CV: which requirement is shown by evidence on the CV, which the vault
/// could show but is left off, and which is not in the vault at all. Worked out from Ayla's match of the vacancy
/// with the vault (the skill behind each requirement) and the skills on each piece of evidence.
public enum ApplicationCoverage {
    public enum State: Equatable, Sendable {
        /// Evidence on the CV shows it: the titles of those entries.
        case shown([String])
        /// Only named among the skills on the CV, without evidence behind it.
        case named
        /// The vault has evidence for it that is off: the entries to turn on.
        case available([String])
        /// Nothing in the vault shows it.
        case missing
    }

    public struct Requirement: Equatable, Sendable, Identifiable {
        public var skill: String
        /// The line from the vacancy.
        public var text: String
        public var state: State

        public var id: String { skill.lowercased() }
        public var isCovered: Bool {
            switch state {
            case .shown, .named: true
            case .available, .missing: false
            }
        }
    }

    public static func requirements(of draft: ApplicationDraft, items: [VaultItem]) -> [Requirement] {
        var seen = Set<String>()
        let asked = (draft.vacancy.matches + draft.vacancy.skillGap).filter { seen.insert($0.skill.lowercased()).inserted }
        let entries = draft.cv.sections.flatMap { section in section.entries.map { (entry: $0, isOn: $0.isVisible && section.isVisible) } }
        return asked.map { link in
            let key = link.skill.lowercased()
            let having = entries.filter { pair in
                items.first { $0.id == pair.entry.sourceItemID }?.skills.contains { $0.lowercased() == key } ?? false
            }
            let on = having.filter(\.isOn)
            let state: State
            if !on.isEmpty {
                state = .shown(on.map(\.entry.title))
            } else if !having.isEmpty {
                state = .available(having.map(\.entry.id))
            } else if draft.cv.skills.contains(where: { $0.lowercased() == key }) {
                state = .named
            } else {
                state = .missing
            }
            return Requirement(skill: link.skill, text: link.requirement, state: state)
        }
    }
}
