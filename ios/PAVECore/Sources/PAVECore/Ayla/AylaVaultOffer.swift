import Foundation

/// When Ayla offers to add something to the vault ("Wil je iets toevoegen?" with Ja and Nee, Figma 976:7971), the same
/// as `web/app/utils/vaultAdd.ts`. The Ayla function asks it with navigation addEvidence or a proposed addVaultItem; an
/// answer about the vault that says she does not see something gets the question too, also from an older function.
public enum AylaVaultOffer {
    public static let question = AylaReply.Question(
        text: "Wil je iets toevoegen?",
        choices: [AylaReply.Choice(id: "yes", label: "Ja"), AylaReply.Choice(id: "no", label: "Nee")]
    )

    // Computed: a Regex is not Sendable, so it cannot be a shared constant.
    private static var addWords: Regex<Substring> { #/toevoeg|aanvul|bewaren|opslaan|zetten/# }
    /// "Ik zie dat niet in je kluis", "Je hebt nog niets in je kluis".
    private static var saysNo: Regex<(Substring, Substring)> { #/\b(niet|geen|niets|niks|nergens)\b/# }
    /// "Open mijn kluis" asks to go there, not what is in it.
    private static var opensVault: Regex<(Substring, Substring)> { #/^(open|ga naar|toon|laat)\b/# }
    private static var yesLabel: Regex<(Substring, Substring)> { #/^(ja|jazeker|ja graag|graag|ja,? graag|ja,? toevoegen|toevoegen|yes)\b/#.ignoresCase() }

    /// The question under Ayla's answer: her own, or "Wil je iets toevoegen?" when she answers about the vault without it.
    /// `asked` is the user's question this reply answers.
    public static func question(for reply: AylaReply?, asked: String) -> AylaReply.Question? {
        guard let reply else { return nil }
        if let question = reply.question { return question }
        return isVaultQuestion(reply, asked: asked) ? question : nil
    }

    /// Whether Ja to the question opens adding evidence.
    public static func offersToAddEvidence(_ reply: AylaReply?, asked: String) -> Bool {
        guard let reply else { return false }
        if reply.navigation?.screen == .addEvidence || reply.proposedAction?.kind == .addVaultItem { return true }
        if isVaultQuestion(reply, asked: asked) { return true }
        guard let question = reply.question else { return false }
        let words = "\(question.text) \(reply.text)".lowercased()
        return words.contains("kluis") && words.contains(addWords)
    }

    public static func isYes(_ label: String) -> Bool {
        label.trimmingCharacters(in: .whitespacesAndNewlines).prefixMatch(of: yesLabel) != nil
    }

    /// The skills Ayla suggested in this reply (a skillSuggestions block), each once.
    public static func suggestedSkills(in reply: AylaReply?) -> [String] {
        var names: [String] = []
        for block in reply?.blocks ?? [] {
            guard case .skillSuggestions(_, let skills) = block else { continue }
            for skill in skills {
                let name = skill.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, !names.contains(name) { names.append(name) }
            }
        }
        return names
    }

    private static func isVaultQuestion(_ reply: AylaReply, asked: String) -> Bool {
        if reply.question != nil { return false }
        if reply.navigation?.screen == .addEvidence { return true }
        let question = asked.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let answer = reply.text.lowercased()
        let opens = question.prefixMatch(of: opensVault) != nil
        if question.contains("kluis"), !opens { return true }
        return answer.contains("kluis") && answer.contains(saysNo) && !opens
    }
}
