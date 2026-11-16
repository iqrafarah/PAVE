import PAVECore

/// A place from the start chips that opens over the chat, like on the web: you see it and keep talking with Ayla about
/// it. While it is open, every question is sent with this place as its context.
enum AylaShelf: String, Identifiable, CaseIterable {
    case vault
    case plan
    case profile

    var id: Self { self }

    var title: String {
        switch self {
        case .vault: "Kluis"
        case .plan: "Plan"
        case .profile: "Profiel"
        }
    }

    var closeTitle: String { "\(title) sluiten" }

    /// Under the title: that you can keep asking Ayla about it.
    var hint: String {
        switch self {
        case .vault: "Vraag Ayla hieronder iets over je kluis."
        case .plan: "Vraag Ayla hieronder iets over je plan."
        case .profile: "Vraag Ayla hieronder iets over je profiel."
        }
    }

    var screen: AylaScreen {
        switch self {
        case .vault: .vault
        case .plan: .plans
        case .profile: .profile
        }
    }
}
