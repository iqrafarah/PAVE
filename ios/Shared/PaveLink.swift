import Foundation

/// The ways into PAVE from outside the app: Siri, Shortcuts, the Action button, Control Center and the widgets.
/// They only open the app, so it always asks for your PIN or Face ID first and shows nothing of you outside it.
nonisolated enum PaveLink: String, CaseIterable, Sendable {
    case talk = "praat-met-ayla"
    case newConversation = "nieuw-gesprek"
    /// Profiel: what you share now and with whom.
    case shares = "gedeeld"
    /// Profiel, asking whether to pause or take back everything you share.
    case stopSharing = "stop-delen"
    /// Vacatures: your applications, from the widget.
    case applications = "sollicitaties"
    /// Profiel › Mijn beursdag, from an invitation at the fair.
    case fairDay = "beursdag"

    static let scheme = "pave"

    var url: URL {
        URL(string: "\(Self.scheme)://ayla/\(rawValue)")!
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host() == "ayla" else { return nil }
        self.init(rawValue: url.lastPathComponent)
    }
}
