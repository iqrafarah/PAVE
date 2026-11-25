import Foundation

/// The first version of a CV and a letter, made on the device from the vault and the vacancy: no AI, and nothing that
/// is not in the vault. Laid out the way a CV is read: every part newest first, the skills the vacancy asks for in
/// front; Ayla can rewrite the texts afterwards.
public enum ApplicationBuilder {
    /// At most this many skills on the CV, the ones the vacancy asks for first.
    public static let maximumSkills = 12

    /// `writesItself`: the texts stay empty for the user to write, with hints in the editor; the data from the vault
    /// is there either way.
    public static func draft(
        for vacancy: Vacancy, items: [VaultItem], name: String, email: String = "", template: ApplicationTemplate = .sage, writesItself: Bool = false
    ) -> ApplicationDraft {
        let relevant = items.filter { $0.archivedAt == nil && $0.status != .rejected }
        let wanted = Set((vacancy.matches + vacancy.skillGap).map { $0.skill.lowercased() })
        func entries(_ categories: Set<VaultCategory>, describes: Bool = true) -> [CVEntry] {
            relevant
                .filter { categories.contains($0.category) }
                .sorted(by: isNewer)
                .map { entry($0, describes: describes) }
        }
        // A diploma or a certificate says what it is by its name, school and year; the story is for work and projects.
        let sections = [
            CVSection(kind: .experience, entries: entries([.workExperience, .internships])),
            CVSection(kind: .education, entries: entries([.diplomas], describes: false)),
            CVSection(kind: .certificates, entries: entries([.certificates, .badges], describes: false)),
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
        let letter = writesItself
            ? LetterContent(
                salutation: "Beste team van \(vacancy.company),",
                paragraphs: (0..<3).map { _ in LetterParagraph(text: "") },
                closing: "Met vriendelijke groet,",
                signature: name
            )
            : letter(for: vacancy, items: relevant, wanted: wanted, name: name)
        return ApplicationDraft(vacancy: vacancy, template: template, showsPhoto: template.hasPhoto, cv: cv, letter: letter)
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
        let opening = vacancy.isOpenApplication
            ? "Graag stel ik mij voor bij \(vacancy.company). Ik ben benieuwd of er bij jullie een plek is waar ik kan bijdragen."
            : "Met veel interesse las ik de vacature \(vacancy.title) bij \(vacancy.company). Graag stel ik mij voor."
        var paragraphs = [LetterParagraph(text: opening)]
        let best = items
            .filter { [.workExperience, .internships, .projects].contains($0.category) }
            .sorted { $0.skills.filter { wanted.contains($0.lowercased()) }.count > $1.skills.filter { wanted.contains($0.lowercased()) }.count }
            .prefix(2)
        for item in best {
            let place = item.organisationName.map { " bij \($0)" } ?? ""
            let skills = item.skills.prefix(3).joined(separator: ", ")
            let what = skills.isEmpty ? "" : " Ik werkte daar met \(skills)."
            paragraphs.append(LetterParagraph(text: "\(item.title)\(place): hier deed ik ervaring op die \(vacancy.isOpenApplication ? "ik graag bij jullie inzet" : "past bij deze functie").\(what)", sourceItemIDs: [item.id]))
        }
        paragraphs.append(LetterParagraph(text: "Ik vertel graag in een gesprek meer over wat ik kan betekenen voor \(vacancy.company)."))
        return LetterContent(salutation: "Beste team van \(vacancy.company),", paragraphs: paragraphs, closing: "Met vriendelijke groet,", signature: name)
    }

    static func entry(_ item: VaultItem, describes: Bool = true) -> CVEntry {
        CVEntry(
            title: item.title,
            organisation: organisation(item),
            period: item.period ?? "",
            description: describes ? item.description ?? "" : "",
            sourceItemID: item.id
        )
    }

    /// "Pixelwerk, Eindhoven"; the place once when the name already says it ("Stedelijk College Eindhoven").
    static func organisation(_ item: VaultItem) -> String {
        let name = item.organisationName ?? ""
        let place = item.organisationLocation ?? ""
        if name.isEmpty || place.isEmpty || name.localizedCaseInsensitiveContains(place) { return name.isEmpty ? place : name }
        return "\(name), \(place)"
    }

    /// Current first, then the newest.
    static func sortDay(_ item: VaultItem) -> VaultDay {
        if item.isCurrent { return VaultDay(year: 9999, month: 12, day: 31) }
        return item.endDate ?? item.issuedOn ?? item.startDate ?? VaultDay(year: 0, month: 1, day: 1)
    }

    /// The order of a CV: what is going on now first (the one that started last on top), then back in time.
    static func isNewer(_ a: VaultItem, _ b: VaultItem) -> Bool {
        let start = VaultDay(year: 0, month: 1, day: 1)
        return (sortDay(a), a.startDate ?? start) > (sortDay(b), b.startDate ?? start)
    }
}
