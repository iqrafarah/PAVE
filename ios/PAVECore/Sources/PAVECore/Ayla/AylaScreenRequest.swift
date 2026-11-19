import Foundation

/// "Open mijn kluis", "ga naar mijn plan": Ayla takes you there herself, as on the web (screenAskedFor). Opening a page
/// changes nothing, so it needs no confirmation.
public enum AylaScreenRequest {
    /// The page a short request asks for, or nil when the question is about something else.
    public static func screen(askedIn text: String) -> AylaScreen? {
        let asked = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard asked.count <= 60, asked.firstMatch(of: openVerbs) != nil else { return nil }
        return screens.first { asked.firstMatch(of: $0.pattern) != nil }?.screen
    }

    /// Where Ayla opens a page after her answer: what she pointed to, or else what was asked; never while she is
    /// building evidence or asking something first.
    public static func screenToOpen(after reply: AylaReply, asked: String) -> AylaReply.Navigation? {
        guard reply.question == nil, reply.accessRequest == nil, !AylaVaultOffer.offersToAddEvidence(reply, asked: asked) else { return nil }
        if let navigation = reply.navigation, opensByItself.contains(navigation.screen) { return navigation }
        return screen(askedIn: asked).map { AylaReply.Navigation(screen: $0) }
    }

    /// The pages Ayla may open by herself.
    public static let opensByItself: [AylaScreen] = [.vault, .vaultItem, .plans, .profile, .settings, .notifications]

    nonisolated(unsafe) private static let openVerbs = /\b(open|opent|ga naar|ga eens naar|breng me naar|neem me mee naar|toon|laat zien)\b/
    nonisolated(unsafe) private static let screens: [(pattern: Regex<Substring>, screen: AylaScreen)] = [
        (/\bkluis\b/, .vault),
        (/\bplan(?:nen)?\b/, .plans),
        (/\bprofiel\b/, .profile),
        (/\binstellingen\b/, .settings),
        (/\b(?:meldingen|notificaties)\b/, .notifications),
    ]
}
