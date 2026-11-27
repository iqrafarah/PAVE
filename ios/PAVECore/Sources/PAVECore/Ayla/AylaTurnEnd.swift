import Foundation

/// How long Ayla waits in silence before she sends what you said. A fixed short pause cut people off while they were
/// thinking ("ik zoek een baan als, eh…"); a long one makes every answer slow. So it depends on how the words end.
public enum AylaTurnEnd {
    /// A clear question or sentence of a few words.
    public static let finished = Duration.milliseconds(1100)
    /// Most things.
    public static let usual = Duration.milliseconds(1600)
    /// One or two words, which are often the start of something.
    public static let short = Duration.milliseconds(2200)
    /// Words that cannot be the end: "en", "met", "eh", "die".
    public static let unfinished = Duration.milliseconds(3000)

    /// Answers that are complete in one word.
    static let complete: Set<String> = [
        "ja", "nee", "jep", "jawel", "nope", "oké", "oke", "ok", "prima", "goed", "graag", "klopt", "stop", "dankjewel",
        "bedankt", "doei", "volgende", "vorige", "klaar", "genoeg", "zeker", "precies",
    ]

    /// Words a sentence does not end on: joining words, articles, most prepositions and filler. Not "die", "het",
    /// "maar", "uit" or "op": Dutch ends on those all the time ("vergelijk deze met die", "doe maar", "zet het uit").
    static let continuing: Set<String> = [
        "en", "of", "want", "dus", "omdat", "als", "de", "een", "met", "van", "voor", "bij", "naar", "tot", "zoals",
        "welke", "mijn", "jouw", "onze", "eh", "ehm", "uh", "uhm", "hm", "hmm", "nou",
        "and", "or", "but", "the", "a", "with", "um",
    ]

    public static func pause(after text: String) -> Duration {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "é" })
            .map(String.init)
        guard let last = words.last else { return usual }
        if trimmed.hasSuffix("?") { return finished }
        if trimmed.hasSuffix(",") || trimmed.hasSuffix("…") || trimmed.hasSuffix("...") || continuing.contains(last) { return unfinished }
        if words.count <= 2 { return words.allSatisfy(complete.contains) ? finished : short }
        if trimmed.hasSuffix(".") && words.count >= 4 { return finished }
        return usual
    }
}
