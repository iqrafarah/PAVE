import PAVECore

/// A place that opens over the chat, from the start chips or when you ask Ayla for it ("open mijn kluis"), like on the web: you see it and keep talking with Ayla about
/// it. While it is open, every question is sent with this place as its context.
enum AylaShelf: String, Identifiable, CaseIterable {
    case vault
    case plan
    case profile
    case settings
    case notifications

    var id: Self { self }

    var title: String {
        switch self {
        case .vault: "Kluis"
        case .plan: "Plan"
        case .profile: "Profiel"
        case .settings: "Instellingen"
        case .notifications: "Meldingen"
        }
    }

    var closeTitle: String { "\(title) sluiten" }

    /// Under the title: that you can keep asking Ayla about it.
    var hint: String {
        switch self {
        case .vault: "Vraag Ayla hieronder iets over je kluis."
        case .plan: "Veeg dit weg en vraag Ayla iets over je plan."
        case .profile: "Veeg dit weg en vraag Ayla iets over je profiel."
        case .settings: "Veeg dit weg om verder te praten met Ayla."
        case .notifications: "Veeg dit weg om verder te praten met Ayla."
        }
    }

    var screen: AylaScreen {
        switch self {
        case .vault: .vault
        case .plan: .plans
        case .profile: .profile
        case .settings: .settings
        case .notifications: .notifications
        }
    }

    /// The place for a page Ayla opens; a vault item opens in the vault.
    init?(_ screen: AylaScreen) {
        switch screen {
        case .vault, .vaultItem: self = .vault
        case .plans: self = .plan
        case .profile: self = .profile
        case .settings: self = .settings
        case .notifications: self = .notifications
        default: return nil
        }
    }

    /// The places with their own full page; the others are a panel.
    var isFullPage: Bool { self == .vault || self == .settings }
}
