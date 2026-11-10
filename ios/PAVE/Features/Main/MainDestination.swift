/// The places you can open yourself from the menu, the same as in the web sidebar.
/// Ayla, the A, always brings you back to the chat.
enum MainDestination: String, CaseIterable, Identifiable {
    case ayla
    case vault
    case plan
    case profile
    case settings
    case notifications

    /// At the top of the menu. Settings open from your account, notifications from the bell.
    static let main: [MainDestination] = [.ayla, .vault, .plan, .profile]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ayla: "Ayla"
        case .vault: "Kluis"
        case .plan: "Plan"
        case .profile: "Profiel"
        case .settings: "Instellingen"
        case .notifications: "Meldingen"
        }
    }

    var icon: MainMenuIcon {
        switch self {
        case .ayla: .aylaLetter
        case .vault: .image(.iconFolder)
        case .plan: .image(.iconMap)
        case .profile: .image(.iconPerson)
        case .settings: .image(.iconSettings)
        case .notifications: .bell
        }
    }
}
