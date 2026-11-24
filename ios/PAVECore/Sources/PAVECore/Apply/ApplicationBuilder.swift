import Foundation

/// The first version of a CV and a letter, made on the device from the vault and the vacancy: no AI, and nothing that
/// is not in the vault. Evidence that fits the vacancy comes first; Ayla can rewrite the texts afterwards.
public enum ApplicationBuilder {
    /// At most this many skills on the CV, the ones the vacancy asks for first.
    public static let maximumSkills = 12

    public static func draft(for vacancy: Vacancy, items: [VaultItem], name: String, email: String = "") -> ApplicationDraft {
        let relevant = items.filter { $0.archivedAt == nil && $0.status != .rejected }
        let wanted = Set((vacancy.matches + vacancy.skillGap).map { $0.skill.lowercased() })
        func score(_ item: VaultItem) -> Int { item.skills.filter { wanted.contains($0.lowercased()) }.count }
        func entries(_ categories: Set<VaultCategory>) -> [CVEntry] {
            relevant
                .filter { categories.contains($0.category) }
                .sorted { (score($0), sortDay($0)) > (score($1), sortDay($1)) }
                .map(entry)
        }
        let sections = [
            CVSection(kind: .experience, entries: entries([.workExperience, .internships])),
            CVSection(kind: .education, entries: entries([.diplomas])),
            CVSection(kind: .certificates, entries: entries([.certificates, .badges])),
            CVSection(kind: .projects, entries: entries([.projects])),
        ]
        let education = relevant.filter { $0.category == .diplomas }.max { sortDay($0) < sortDay($1) }
        let cv = CVContent(
            name: name,
            headline: education.map { "Student \($0.title)" } ?? "",
            email: email,
            sections: sections,
            skills: skills(from: relevant, wanted: wanted)
        )
        return ApplicationDraft(vacancy: vacancy, cv: cv, letter: letter(for: vacancy, items: relevant, wanted: wanted, name: name))
    }

    /// The skills of the evidence, those the vacancy asks for first, each once.
    static func skills(from items: [VaultItem], wanted: Set<String>) -> [String] {
        var seen = Set<String>()
        let all = items.flatMap(\.skills).filter { seen.insert($0.lowercased()).inserted }
        let first = all.filter { wanted.contains($0.lowercased()) }
        let rest = all.filter { !wanted.contains($0.lowercased()) }
        return Array((first + rest).prefix(maximumSkills))
    }

    /// A plain letter with only what the vault says; Ayla makes it personal later.
    static func letter(for vacancy: Vacancy, items: [VaultItem], wanted: Set<String>, name: String) -> LetterContent {
        var paragraphs = [LetterParagraph(text: "Met veel interesse las ik de vacature \(vacancy.title) bij \(vacancy.company). Graag stel ik mij voor.")]
        let best = items
            .filter { [.workExperience, .internships, .projects].contains($0.category) }
            .sorted { $0.skills.filter { wanted.contains($0.lowercased()) }.count > $1.skills.filter { wanted.contains($0.lowercased()) }.count }
            .prefix(2)
        for item in best {
            let place = item.organisationName.map { " bij \($0)" } ?? ""
            let skills = item.skills.prefix(3).joined(separator: ", ")
            let what = skills.isEmpty ? "" : " Ik werkte daar met \(skills)."
            paragraphs.append(LetterParagraph(text: "\(item.title)\(place): hier deed ik ervaring op die past bij deze functie.\(what)", sourceItemIDs: [item.id]))
        }
        paragraphs.append(LetterParagraph(text: "Ik vertel graag in een gesprek meer over wat ik kan betekenen voor \(vacancy.company)."))
        return LetterContent(salutation: "Beste team van \(vacancy.company),", paragraphs: paragraphs, closing: "Met vriendelijke groet,", signature: name)
    }

    static func entry(_ item: VaultItem) -> CVEntry {
        CVEntry(
            title: item.title,
            organisation: [item.organisationName, item.organisationLocation].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "),
            period: item.period ?? "",
            description: item.description ?? "",
            sourceItemID: item.id
        )
    }

    /// Current first, then the newest.
    static func sortDay(_ item: VaultItem) -> VaultDay {
        if item.isCurrent { return VaultDay(year: 9999, month: 12, day: 31) }
        return item.endDate ?? item.issuedOn ?? item.startDate ?? VaultDay(year: 0, month: 1, day: 1)
    }
}
