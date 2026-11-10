/// The kinds of evidence in the vault. The raw values are the codes in the database and in `shared/ayla/reply.schema.json`.
public enum VaultCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case diplomas
    case certificates
    case badges
    case projects
    case workExperience
    case internships
    case skills
    case feedback
    case reflections

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .diplomas: "Diploma's"
        case .certificates: "Certificaten"
        case .badges: "Badges"
        case .projects: "Projecten"
        case .workExperience: "Werkervaring"
        case .internships: "Stages"
        case .skills: "Vaardigheden"
        case .feedback: "Feedback"
        case .reflections: "Reflecties"
        }
    }

    /// One of the same kind, for "Nieuw diploma" and the category picker.
    public var singularTitle: String {
        switch self {
        case .diplomas: "Diploma"
        case .certificates: "Certificaat"
        case .badges: "Badge"
        case .projects: "Project"
        case .workExperience: "Werkervaring"
        case .internships: "Stage"
        case .skills: "Vaardigheid"
        case .feedback: "Feedback"
        case .reflections: "Reflectie"
        }
    }

    /// Something you obtained on one day has a date; something you did for a while has a start and an end.
    public var hasPeriod: Bool {
        switch self {
        case .diplomas, .certificates, .badges: false
        case .projects, .workExperience, .internships, .skills, .feedback, .reflections: true
        }
    }

    /// The folders that are always on top of the vault, as in the design. Other categories appear once they hold something.
    public static let featured: [VaultCategory] = [.certificates, .diplomas, .feedback, .projects]
}
