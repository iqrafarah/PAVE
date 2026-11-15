import Foundation

/// Ayla's answer as it is said when nothing can be seen: by Siri, or while talking with the iPhone in a pocket. The
/// choices that would be buttons on screen are said out loud, and a long answer stops after a few sentences.
public enum AylaSpokenReply {
    /// How many sentences Siri reads at most; the rest is in the chat.
    static let maximumSentences = 4

    /// What to say for the choices of a question, or nil without choices. `canNod` adds that a nod or head shake works.
    public static func choicesLine(_ choices: [String], canNod: Bool = false) -> String? {
        let labels = choices.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard labels.count >= 2 else { return nil }
        if labels.contains(where: AylaVaultOffer.isYes), labels.contains(where: AylaVaultOffer.isNo) {
            return canNod ? "Zeg ja of nee, of knik of schud je hoofd." : "Zeg ja of nee."
        }
        let spoken = labels.dropLast().joined(separator: ", ") + " of " + labels[labels.count - 1]
        return "Je kunt kiezen: \(spoken)."
    }

    /// The whole answer for Siri: her text and question, without markdown, cut after a few sentences, with the choices
    /// said out loud and, when there is more to do, how to go on in PAVE.
    public static func forSiri(_ reply: AylaReply, choices: [String], goOn: String) -> String {
        let text = [reply.text, reply.question?.text]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let plain = text
            .replacingOccurrences(of: #"[*_#`>]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let sentences = AylaCaptions.sentences(in: plain)
        var spoken = sentences.prefix(maximumSentences).joined(separator: " ")
        let wasCut = sentences.count > maximumSentences
        if let line = choicesLine(choices) { spoken += " " + line }
        if wasCut || !choices.isEmpty || reply.proposedAction != nil || reply.navigation != nil { spoken += " " + goOn }
        return spoken.trimmingCharacters(in: .whitespaces)
    }
}
