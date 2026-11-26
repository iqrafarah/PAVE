import Foundation

/// "Skill-kompas": over the vacancies you kept, found and applied for, which skills are asked most, which of them you
/// can show with evidence, and which you still miss, the most asked first. What you miss most often is the step that
/// pays off most.
public enum SkillCompass {
    public struct Skill: Identifiable, Equatable, Sendable {
        public var id: String { name.lowercased() }
        public let name: String
        /// The vacancies that ask for it, by title and company.
        public let vacancies: [String]
        /// Evidence in the vault that names this skill, by title; empty for a skill you still miss.
        public let evidence: [String]
        public let isVerified: Bool

        public var count: Int { vacancies.count }
    }

    public struct Result: Equatable, Sendable {
        public let missing: [Skill]
        public let have: [Skill]
        public let vacancyCount: Int

        /// The one skill to work on first: missing in the most vacancies.
        public var nextBest: Skill? { missing.first }
    }

    public static func build(vacancies: [Vacancy], items: [VaultItem]) -> Result {
        var seen = Set<String>()
        let unique = vacancies.filter { seen.insert($0.id).inserted }
        var asked: [String: (name: String, vacancies: [String], missing: Bool)] = [:]
        for vacancy in unique {
            let label = vacancy.company.isEmpty ? vacancy.title : "\(vacancy.title) bij \(vacancy.company)"
            for (link, isGap) in vacancy.matches.map({ ($0, false) }) + vacancy.skillGap.map({ ($0, true) }) {
                let name = link.skill.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                let key = name.lowercased()
                var entry = asked[key] ?? (name, [], isGap)
                if !entry.vacancies.contains(label) { entry.vacancies.append(label) }
                // Missing for one vacancy but matched for another: the vault says whether you have it.
                entry.missing = entry.missing && isGap
                asked[key] = entry
            }
        }
        let usable = items.filter { $0.archivedAt == nil && $0.status != .rejected }
        func evidence(for skill: String) -> [VaultItem] {
            usable.filter { item in item.skills.contains { $0.caseInsensitiveCompare(skill) == .orderedSame } }
        }
        var missing: [Skill] = []
        var have: [Skill] = []
        for (_, entry) in asked {
            let proof = evidence(for: entry.name)
            let skill = Skill(name: entry.name, vacancies: entry.vacancies, evidence: proof.map(\.title), isVerified: proof.contains { $0.status == .verified })
            if proof.isEmpty && entry.missing { missing.append(skill) } else { have.append(skill) }
        }
        let order: (Skill, Skill) -> Bool = { $0.count != $1.count ? $0.count > $1.count : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return Result(missing: missing.sorted(by: order), have: have.sorted(by: order), vacancyCount: unique.count)
    }
}
