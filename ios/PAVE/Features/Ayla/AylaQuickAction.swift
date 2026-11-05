/// Questions behind the plus button in the text field.
enum AylaQuickAction: String, CaseIterable, Identifiable {
    case vacancies
    case curriculumVitae
    case plan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vacancies: "Vacatures zoeken"
        case .curriculumVitae: "Hulp bij mijn cv"
        case .plan: "Een plan maken"
        }
    }

    var question: String {
        switch self {
        case .vacancies: "Kun je vacatures zoeken die bij mij passen?"
        case .curriculumVitae: "Kun je me helpen met mijn cv?"
        case .plan: "Kun je me helpen een ontwikkelplan te maken?"
        }
    }
}
