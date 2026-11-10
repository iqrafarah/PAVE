import SwiftUI

enum VaultCategory: String, CaseIterable, Identifiable, Hashable {
    case all
    case diplomas
    case certificates
    case badges
    case projects
    case experiences
    case internships
    case skills
    case feedback
    case reflections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Alle items"
        case .diplomas: "Diploma's"
        case .certificates: "Certificaten"
        case .badges: "Badges"
        case .projects: "Projecten"
        case .experiences: "Ervaringen"
        case .internships: "Stages"
        case .skills: "Skills"
        case .feedback: "Feedback"
        case .reflections: "Reflecties"
        }
    }

    var filterTitle: String {
        self == .all ? "Alle" : title
    }

    /// Counts shown in the supplied mobile prototype. They are design data, not live account totals.
    var prototypeCount: Int {
        switch self {
        case .all: 50
        case .diplomas: 5
        case .certificates: 15
        case .badges, .internships, .skills, .feedback, .reflections: 0
        case .projects: 20
        case .experiences: 10
        }
    }

    var tint: Color {
        switch self {
        case .all, .experiences, .internships, .skills, .reflections: .cardTintLavender
        case .diplomas: .cardTintApricot
        case .certificates, .badges, .projects, .feedback: .cardTintGreen
        }
    }

    static let folderCategories: [VaultCategory] = [.certificates, .diplomas, .feedback, .projects]

    var folderIcon: String {
        switch self {
        case .certificates: "IconCheckBadgeSolid"
        case .diplomas: "IconAcademicCapSolid"
        case .feedback: "IconChatBubbleLeftEllipsisSolid"
        case .projects: "IconWrenchScrewdriverSolid"
        default: "IconFolder"
        }
    }
}
