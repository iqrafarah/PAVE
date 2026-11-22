import Foundation

/// When Ayla offers to add something to the vault ("Wil je iets toevoegen?" with Ja and Nee, Figma 976:7971), the same
/// as `web/app/utils/vault/vaultAdd.ts`. The Ayla function asks it with navigation addEvidence or a proposed
/// addVaultItem. Only a request to put something in the vault gets the question without that; asking what is in the
/// vault does not, and neither does her question whether she may look in it (accessRequest).
public enum AylaVaultOffer {
    /// The choice "Kies zelf" on Ayla's question about the vault: the app opens the picker instead of answering.
    public static let chooseChoiceID = "choose"

    /// "Zoek opnieuw met alles uit mijn kluis", "gebruik mijn hele kluis": not only the items you picked any more.
    /// The same as `grantsWholeVault` in the Ayla function: a question about the vault ("gebruik je alles uit mijn
    /// kluis?"), a remark that only names it ("ik heb mijn hele kluis opgeruimd") and anything with "niet" or "geen"
    /// change nothing; "niet alleen mijn diploma" asks for more, not less.
    public static func usesWholeVault(_ text: String) -> Bool {
        let said = AylaScreenRequest.normalized(text)
        guard !AylaScreenRequest.matches(said, #"^(staat|staan|is|zijn|wat|welke|welk|waar|hoe|heb|zit|zitten|waarom|wanneer|wie)\b"#) else { return false }
        let withoutMore = said.replacingOccurrences(of: #"\bniet alleen\b"#, with: " ", options: .regularExpression)
        guard !AylaScreenRequest.matches(withoutMore, #"\b(niet|geen|nooit)\b"#) else { return false }
        let mine = "(mijn|m'n|de)"
        let whole = "(hele|volledige|complete)"
        let patterns = [
            "\\b(met|op basis van|aan de hand van) (alles|al het bewijs) (uit|in|van) \(mine) (\(whole) )?kluis\\b",
            "\\b(met|op basis van|aan de hand van) \(mine) \(whole) kluis\\b",
            "\\b(gebruik|neem|pak)\\b(?! (je|jij)\\b).*(\\b\(mine) \(whole) kluis\\b|\\balles (uit|in|van) \(mine) kluis\\b)",
            "\\b(kijk|zoek) in \(mine) \(whole) kluis\\b",
            "\\bmag\\b.*(\\b\(mine) \(whole) kluis\\b|\\balles (uit|in|van) \(mine) kluis\\b).*\\b(gebruiken|bekijken|zien|inzien)\\b",
        ]
        return patterns.contains { AylaScreenRequest.matches(said, $0) }
    }

    /// "Kijk niet meer in mijn kluis", "ik trek mijn toestemming in": Ayla may not look any more, so what you picked
    /// for this conversation is let go as well. The same as `revokesVault` in the Ayla function.
    public static func takesVaultBack(_ text: String) -> Bool {
        let said = AylaScreenRequest.normalized(text)
        let patterns = [
            #"\b(kijk|gebruik|lees|zoek)\b.*\b(niet meer|niet langer)\b.*\bkluis\b"#,
            #"\b(stop met|hou op met)\b.*\bkluis\b"#,
            #"\bkluis\b.*\b(niet meer|niet langer)\b.*\b(gebruiken|bekijken|zien|inzien|kijken|lezen)\b"#,
            #"\b(niet meer|niet langer)\b.*\bkluis\b.*\b(gebruiken|bekijken|zien|inzien|kijken|lezen)\b"#,
            #"\b(trek|intrekken|ingetrokken)\b.*\b(toestemming|kluis)\b"#,
            #"\btoestemming\b.*\b(in ?trek|intrekken|terug)\b"#,
        ]
        return patterns.contains { AylaScreenRequest.matches(said, $0) }
    }

    /// "Kies zelf", "laat mezelf kiezen", "ik wil het zelf bepalen", "laat mij kiezen": you want to pick the items
    /// yourself, said in your own words. Not when you say you do not want that.
    public static func wantsToChoose(_ text: String) -> Bool {
        let said = AylaScreenRequest.normalized(text)
        guard !said.isEmpty, said.split(separator: " ").count <= 9, !AylaScreenRequest.matches(said, #"\b(niet|geen)\b"#) else { return false }
        let own = #"(?:zelf|mezelf|zelluf|eigen)"#
        let pick = #"(?:kies|kiezen|uitkiezen|selecteer|selecteren|bepaal|bepalen|uitzoeken|aangeven|aanwijzen|keuze)"#
        return AylaScreenRequest.matches(said, "\\b\(own)\\b.*\\b\(pick)\\b")
            || AylaScreenRequest.matches(said, "\\b\(pick)\\b.*\\b\(own)\\b")
            || AylaScreenRequest.matches(said, #"^(?:(?:ja|nee|oke|ok) )?(?:laat|ik wil|ik ga|mag ik|wil ik)(?: \w+){0,3} (?:kiezen|selecteren|uitkiezen)$"#)
            || AylaScreenRequest.matches(said, #"^(?:ik )?(?:kies|kiezen|selecteren)$"#)
    }

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
        // Just said no to her offer: the app does not offer it again by itself (web brain declinedOffer).
        guard !isNo(asked), isVaultQuestion(reply, asked: asked) else { return nil }
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
        if isNo(asked) { return false }
        if isVaultQuestion(reply, asked: asked) { return lastQuestion(in: reply.text) != .open }
        guard let question = reply.question, !question.text.contains(consentAsk) else { return false }
        let words = "\(question.text) \(reply.text)".lowercased()
        return words.contains("kluis") && words.contains(addWords)
    }

    /// Ayla's last question is whether she may put it in the vault ("Zal ik deze stage zo in je kluis zetten?"), not a
    /// question about a detail of it. Only then does a yes in words count as the confirmation to save.
    public static func asksToPutInVault(_ reply: AylaReply?) -> Bool {
        guard let reply, reply.accessRequest == nil else { return false }
        let text = [reply.text, reply.question?.text].compactMap { $0 }.joined(separator: " ")
        guard let last = sentences(of: text).last(where: { $0.hasSuffix("?") })?.lowercased() else { return false }
        return last.contains("kluis") && last.contains(addWords) && !last.contains(openWords)
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

    /// A short answer in words that says yes to what Ayla proposed ("Graag", "Zet er maar in", "Ja dat klopt"). Not when
    /// it also holds a reservation ("ja, maar eerst de datum aanpassen"), a question, or more than a few words.
    public static func isConfirmation(_ text: String) -> Bool {
        let cleaned = text.lowercased()
            .replacingOccurrences(of: #"[.,!…]+"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !cleaned.isEmpty, cleaned.count <= 7, !text.contains("?") else { return false }
        let reservations: Set<String> = ["nee", "niet", "geen", "wacht", "eerst", "aanpassen", "verander", "veranderen", "anders", "nog", "toch", "alleen"]
        guard cleaned.allSatisfy({ !reservations.contains($0) }), !(cleaned.count > 1 && cleaned[1] == "maar") else { return false }
        let starters: Set<String> = ["ja", "jazeker", "graag", "klopt", "prima", "oké", "oke", "ok", "okay", "top", "goed", "perfect", "zeker", "natuurlijk", "yes", "akkoord", "doen", "doe", "zet", "toevoegen", "bewaar", "sla", "mooi"]
        return starters.contains(cleaned[0])
    }

    private static var noLabel: Regex<(Substring, Substring)> { #/^(nee|nee,? dank je|liever niet|niet nu|no)\b/#.ignoresCase() }

    public static func isNo(_ label: String) -> Bool {
        label.trimmingCharacters(in: .whitespacesAndNewlines).prefixMatch(of: noLabel) != nil
    }

    /// Ayla's last question is one for Ja or Nee: not a question for words ("Wat wil je toevoegen?") and not a choice
    /// between things ("Wil je een diploma of een stage toevoegen?").
    /// Ayla's last question in her text, if she asked one.
    public static func lastQuestionSentence(in text: String) -> String? {
        sentences(of: text).last(where: { $0.hasSuffix("?") })
    }

    public static func endsWithYesNoQuestion(_ text: String) -> Bool {
        guard let last = sentences(of: text).last(where: { $0.hasSuffix("?") }) else { return false }
        return !last.contains(openWords) && !last.lowercased().contains(" of ")
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
