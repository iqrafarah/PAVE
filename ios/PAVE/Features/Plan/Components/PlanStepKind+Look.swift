import PAVECore
import SwiftUI

extension PavePlanStep.Kind {
    /// The kinds the user can choose for a step of their own.
    static let choosable: [PavePlanStep.Kind] = [
        .general, .conversation, .research, .evidence, .verification, .document, .profile, .contact, .action, .reflection, .milestone,
    ]

    /// The icon of a kind of step; a kind the app does not know yet looks like a general step.
    @MainActor var icon: ImageResource {
        switch self {
        case .conversation: .iconChat
        case .research: .iconSearch
        case .evidence: .iconFolder
        case .verification: .iconShieldCheck
        case .document: .iconDocumentTextOutline
        case .action: .iconRocketLaunchOutline
        case .reflection: .iconLightBulbOutline
        case .milestone: .iconFlag
        case .profile: .iconPerson
        case .contact: .iconMail
        default: .iconMap
        }
    }

    /// The same, as an SF Symbol, for the Lock Screen and the Dynamic Island.
    var symbol: String {
        switch self {
        case .conversation: "bubble.left"
        case .research: "magnifyingglass"
        case .evidence: "folder"
        case .verification: "checkmark.shield"
        case .document: "doc.text"
        case .action: "figure.walk"
        case .reflection: "lightbulb"
        case .milestone: "flag"
        case .profile: "person"
        case .contact: "envelope"
        default: "map"
        }
    }

    var title: String {
        switch self {
        case .conversation: "Gesprek met Ayla"
        case .research: "Uitzoeken"
        case .evidence: "Bewijs in je kluis"
        case .verification: "Laten verifiëren"
        case .document: "Schrijven"
        case .action: "Zelf doen"
        case .reflection: "Terugkijken"
        case .milestone: "Mijlpaal"
        case .profile: "Profiel"
        case .contact: "Contact"
        default: "Algemeen"
        }
    }

    /// The place in PAVE where this kind of step is done, besides talking it through with Ayla.
    var destination: MainDestination? {
        switch self {
        case .evidence, .verification: .vault
        case .profile: .profile
        case .contact: .notifications
        default: nil
        }
    }
}

extension MainDestination {
    /// The button on a step that leads here.
    var planStepAction: String {
        switch self {
        case .vault: "Open je kluis"
        case .profile: "Open je profiel"
        case .notifications: "Open Meldingen"
        default: "Open \(title)"
        }
    }
}
