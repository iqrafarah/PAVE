import SwiftUI

enum VaultCategory: String, CaseIterable, Identifiable, Hashable {
    case all
    case diplomas
    case certificates
    case projects
    case experiences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Alle items"
        case .diplomas: "Diploma's"
        case .certificates: "Certificaten"
        case .projects: "Projecten"
        case .experiences: "Ervaringen"
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
        case .projects: 20
        case .experiences: 10
        }
    }

    var tint: Color {
        switch self {
        case .all, .experiences: .cardTintLavender
        case .diplomas: .cardTintApricot
        case .certificates, .projects: .cardTintGreen
        }
    }
}
