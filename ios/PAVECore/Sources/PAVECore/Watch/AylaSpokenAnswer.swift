import Foundation

/// A spoken Ja or Nee to a question on the Watch, such as "Zal ik dit onthouden?". Only short, clear answers count;
/// anything else is a new question for Ayla, so nothing is saved by accident.
public enum AylaSpokenAnswer {
    private static let yes: Set<String> = [
        "ja", "jazeker", "ja graag", "graag", "ja hoor", "ja doe maar", "doe maar", "prima", "goed", "oké", "oke", "ok",
        "is goed", "ja is goed", "zeker", "ja zeker", "onthoud het", "onthoud dat", "ja onthoud het", "ja onthoud dat",
    ]
    private static let no: Set<String> = [
        "nee", "nee dank je", "nee bedankt", "nee hoor", "liever niet", "niet doen", "nee niet doen", "hoeft niet",
        "nee hoeft niet", "laat maar", "nee laat maar", "niet onthouden", "nee niet onthouden",
    ]

    /// `true` for yes, `false` for no, `nil` when it is something else.
    public static func interpret(_ text: String) -> Bool? {
        let plain = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_NL"))
            .lowercased()
            .components(separatedBy: CharacterSet.letters.union(.whitespaces).inverted)
            .joined()
            .split(separator: " ")
            .joined(separator: " ")
        if yes.contains(plain) { return true }
        if no.contains(plain) { return false }
        return nil
    }
}
