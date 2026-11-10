import Foundation

/// The ways into PAVE from outside the app: Siri, Shortcuts, the Action button, Control Center and the widgets.
/// They only open the app, so it always asks for your PIN or Face ID first and shows nothing of you outside it.
nonisolated enum PaveLink: String, CaseIterable, Sendable {
    case talk = "praat-met-ayla"
    case newConversation = "nieuw-gesprek"

    static let scheme = "pave"

    var url: URL {
        URL(string: "\(Self.scheme)://ayla/\(rawValue)")!
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host() == "ayla" else { return nil }
        self.init(rawValue: url.lastPathComponent)
    }
}
