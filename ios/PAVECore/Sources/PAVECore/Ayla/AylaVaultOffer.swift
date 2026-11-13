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
    private static var openWords: Regex<Substring> { #/^(?:wat|welke?|hoe|wanneer|waar\w*|wie|waarom|hoeveel|hoelang)\b/#.ignoresCase() }
    private static var consentAsk: Regex<Substring> { #/\bmag ik\b[^.?!]*\bkluis\b[^.?!]*\bkijken\b/#.ignoresCase() }
    private static var yesLabel: Regex<(Substring, Substring)> { #/^(ja|jazeker|ja graag|graag|ja,? graag|ja,? toevoegen|toevoegen|yes)\b/#.ignoresCase() }

    /// The question under Ayla's answer: her own, or "Wil je iets toevoegen?" when she answers about the vault without it.
    /// `asked` is the user's question this reply answers.
    public static func question(for reply: AylaReply?, asked: String) -> AylaReply.Question? {
        guard let reply else { return nil }
        if let question = reply.question { return question }
        guard isVaultQuestion(reply, asked: asked) else { return nil }
        switch lastQuestion(in: reply.text) {
        // "Wat wil je toevoegen?": the user answers in words.
        case .open: return nil
        // "Zal ik het toevoegen?": Ja and Nee, without asking it again.
        case .yesNo: return AylaReply.Question(text: "", choices: question.choices)
        case nil: return question
        }
    }

    /// Whether Ja to the question opens adding evidence. Not when Ayla asked whether she may look in the vault.
    public static func offersToAddEvidence(_ reply: AylaReply?, asked: String) -> Bool {
        guard let reply, reply.accessRequest == nil else { return false }
        if reply.navigation?.screen == .addEvidence || reply.proposedAction?.kind == .addVaultItem { return true }
        if isVaultQuestion(reply, asked: asked) { return lastQuestion(in: reply.text) != .open }
        guard let question = reply.question, !question.text.contains(consentAsk) else { return false }
        let words = "\(question.text) \(reply.text)".lowercased()
        return words.contains("kluis") && words.contains(addWords)
    }

    public enum LastQuestion: Equatable {
        case open
        case yesNo
    }

    /// Ayla's last question: one the user answers in words, or one answered with Ja or Nee. A sentence after it
    /// ("Bijvoorbeeld een diploma.") does not change that.
    public static func lastQuestion(in text: String) -> LastQuestion? {
        guard let last = sentences(of: text).last(where: { $0.hasSuffix("?") }) else { return nil }
        return last.contains(openWords) ? .open : .yesNo
    }

    private static func sentences(of text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            if character.isNewline {
                result.append(current)
                current = ""
                continue
            }
            current.append(character)
            if ".!?".contains(character) {
                result.append(current)
                current = ""
            }
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Ayla's text already contains her question (older conversations, or a model that asked it twice), so the question
    /// is not shown a second time. Case and the punctuation at the end do not count.
    public static func isAlreadyAsked(_ question: String, in text: String) -> Bool {
        let asked = normalized(question)
        return !asked.isEmpty && normalized(text).contains(asked)
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[?.!…\s]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
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
