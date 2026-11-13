import Foundation

/// When Ayla offers to add something to the vault ("Wil je iets toevoegen?" with Ja and Nee, Figma 976:7971), the same
/// as `web/app/utils/vault/vaultAdd.ts`. The Ayla function asks it with navigation addEvidence or a proposed
/// addVaultItem. Only a request to put something in the vault gets the question without that; asking what is in the
/// vault does not, and neither does her question whether she may look in it (accessRequest).
public enum AylaVaultOffer {
    public static let question = AylaReply.Question(
        text: "Wil je iets toevoegen?",
        choices: [AylaReply.Choice(id: "yes", label: "Ja"), AylaReply.Choice(id: "no", label: "Nee")]
    )

    // Computed: a Regex is not Sendable, so it cannot be a shared constant.
    private static var addWords: Regex<Substring> { #/toevoeg|aanvul|bewaar|opsla|\bzet/# }
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
        guard let reply, reply.accessRequest == nil else { return false }
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
        if reply.question != nil || reply.accessRequest != nil { return false }
        if reply.navigation?.screen == .addEvidence { return true }
        let question = asked.lowercased()
        return question.contains("kluis") && question.contains(addWords)
    }
}
