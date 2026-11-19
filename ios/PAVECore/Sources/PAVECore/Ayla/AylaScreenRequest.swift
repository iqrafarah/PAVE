import Foundation

/// "Open mijn kluis", "ga naar mijn plan", "kun je mijn instellingen openen": Ayla takes you there herself, as on the
/// web (screenAskedFor). Opening a page changes nothing, so it needs no confirmation.
public enum AylaScreenRequest {
    /// The page a request asks for, or nil when the question is about something else. The page has to be what is
    /// opened ("toon mijn profiel"), not just a word in the question ("toon vacatures bij mijn profiel").
    public static func screen(askedIn text: String) -> AylaScreen? {
        let asked = normalized(text)
        guard asked.count <= 120, !matches(asked, #"\b(niet|geen|sluit|sluiten|dicht)\b"#) else { return nil }
        return screens.first { names, _ in
            let name = "(?:\(names))"
            return matches(asked, "^\(fillers)\(name)$")
                || matches(asked, #"\b(?:open|opent|openen|toon|bekijk|ga naar|ga eens naar|ga even naar|breng me naar|breng mij naar|neem me mee naar) "# + "\(fillers)\(name)\\b")
                || matches(asked, "\\b\(name) \(fillers)(?:openen|open|bekijken|tonen)\\b")
                || matches(asked, "\\blaat \(fillers)\(name) zien\\b")
                || matches(asked, "\\blaat \(fillers)zien \(fillers)\(name)\\b")
                || matches(asked, #"\b(?:wil|mag) ik "# + "\(fillers)\(name) zien\\b")
                || matches(asked, "^naar \(fillers)\(name)\\b")
                || matches(asked, #"\b(?:wil|wou|mag|kan|kun|ga|gaan)(?: \w+){0,2} naar "# + "\(fillers)\(name)\\b")
        }?.screen
    }

    /// The page when the request is nothing but opening it ("open kluis", "kun je mijn instellingen openen?"): the app
    /// then just opens it, without an answer from Ayla. Nil when more is asked ("open instellingen en zet donker aan").
    public static func screenOnlyAsked(in text: String) -> AylaScreen? {
        guard let screen = screen(askedIn: text) else { return nil }
        let names = screens.flatMap { $0.names.split(separator: "|").map(String.init) }
        let isOnlyOpening = normalized(text).split(separator: " ").allSatisfy { openingWords.contains(String($0)) || names.contains(String($0)) }
        return isOnlyOpening ? screen : nil
    }

    private static let openingWords: Set<String> = [
        "open", "opent", "openen", "toon", "tonen", "bekijk", "bekijken", "ga", "gaan", "naar", "breng", "neem", "mee", "laat",
        "zien", "wil", "wou", "mag", "kan", "kun", "kunt", "ik", "je", "jij", "ayla", "hey", "hé", "hoi", "eens", "even", "ff",
        "me", "mij", "mijn", "m'n", "mn", "de", "het", "jouw", "maar", "dan", "nu", "graag", "alsjeblieft", "aub",
    ]

    /// "Ja" or "Graag" to Ayla's own "Wil je naar je instellingen gaan?": the page she offered to open.
    public static func screen(confirmedBy answer: String, after reply: AylaReply?) -> AylaReply.Navigation? {
        guard let reply, AylaVaultOffer.isYes(answer), reply.accessRequest == nil,
              !AylaVaultOffer.offersToAddEvidence(reply, asked: "") else { return nil }
        let lastSentence = reply.text.split(whereSeparator: { ".!\n".contains($0) }).last.map(String.init) ?? ""
        guard reply.question != nil || lastSentence.contains("?") else { return nil }
        if let navigation = reply.navigation, opensByItself.contains(navigation.screen) { return navigation }
        let offered = reply.question.flatMap { screen(askedIn: $0.text) } ?? screen(askedIn: lastSentence)
        return offered.map { AylaReply.Navigation(screen: $0) }
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

    /// The pages the brain knows; only these go along as the place a question is asked from.
    public static let knownToBrain: [AylaScreen] = [.home, .chat, .vault, .vaultItem, .addEvidence, .plans, .vacancies, .profile, .settings]

    private static let screens: [(names: String, screen: AylaScreen)] = [
        ("kluis", .vault),
        ("plan|plannen|ontwikkelplan", .plans),
        ("profiel", .profile),
        ("instellingen|settings", .settings),
        ("meldingen|notificaties", .notifications),
    ]

    /// Small words that may stand between "open" and the page.
    private static let fillers = "(?:(?:eens|even|ff|me|mij|mijn|m'n|mn|de|het|je|jouw|maar|dan|nu|graag|alsjeblieft|aub) )*"

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: #"[.,!?;:]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
