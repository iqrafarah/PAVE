import Foundation
import os

/// PAVE's words in another language, from the table in `Localizable.xcstrings` in the app's bundle. A text that is not
/// in the table stays Dutch. Keys with `%@` stand for texts with a value in them, such as "Na %@ minuten": the value is
/// taken from the Dutch text and put in the same place in the translation. Shared by the iPhone and the Watch.
public final class TranslationTable: @unchecked Sendable {
    private let exact: [String: String]
    private let patterns: [(regex: NSRegularExpression, translation: String, isLoose: Bool)]
    private let cache = OSAllocatedUnfairLock<[String: String]>(initialState: [:])

    /// The table for a language code such as "en" or "pap".
    public init(localization: String, bundle: Bundle = .main) {
        let url = bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: localization)
        let entries = url.flatMap { NSDictionary(contentsOf: $0) as? [String: String] } ?? [:]
        exact = entries
        patterns = entries.compactMap { key, value in
            guard key.contains("%@"), Self.hasEnoughWords(key) else { return nil }
            let parts = key.components(separatedBy: "%@").map(NSRegularExpression.escapedPattern(for:))
            let pattern = "^" + parts.joined(separator: "(.+?)") + "$"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
            return (regex, value, Self.letters(in: key) < 6)
        }
        // Longer keys first, so "Na %@ minuten" does not lose to a shorter key that also fits.
        .sorted { $0.regex.pattern.count > $1.regex.pattern.count }
    }

    public func translate(_ text: String) -> String {
        if let hit = exact[text] { return hit }
        if let hit = cache.withLock({ $0[text] }) { return hit }
        var result = text
        // Long texts are messages and documents, not PAVE's own words.
        if text.count <= 400 {
            let range = NSRange(text.startIndex..., in: text)
            for (regex, translation, isLoose) in patterns {
                guard let match = regex.firstMatch(in: text, range: range) else { continue }
                let values = (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
                // A key with few words of its own, like "%@ bij %@", would also fit a sentence you wrote yourself:
                // it only counts when each value is a name or a number of at most two words.
                if isLoose, values.contains(where: { $0.split(separator: " ").count > 2 }) { continue }
                // A value can be a translatable text itself, such as "morgen" in "wordt dan morgen verwijderd".
                result = Self.fill(translation, with: values.map { $0 == text ? $0 : translate($0) })
                break
            }
        }
        let translated = result
        cache.withLock { cache in
            if cache.count > 2000 { cache.removeAll() }
            cache[text] = translated
        }
        return translated
    }

    /// Puts the values in the `%@`s of a translation, in order, or by number for `%1$@`.
    public static func fill(_ translation: String, with values: [String]) -> String {
        var output = ""
        var next = 0
        var rest = Substring(translation)
        while let percent = rest.firstIndex(of: "%") {
            output += rest[..<percent]
            let after = rest[rest.index(after: percent)...]
            if after.hasPrefix("@") {
                output += next < values.count ? values[next] : ""
                next += 1
                rest = after.dropFirst()
            } else if let dollar = after.firstIndex(of: "$"), let number = Int(after[..<dollar]), number > 0,
                      after[after.index(after: dollar)...].hasPrefix("@") {
                output += number - 1 < values.count ? values[number - 1] : ""
                rest = after[after.index(dollar, offsetBy: 2)...]
            } else {
                output += "%"
                rest = after
            }
        }
        return output + rest
    }

    /// A key of only values, like "%@ · %@", would fit almost any text.
    private static func hasEnoughWords(_ key: String) -> Bool {
        letters(in: key) >= 3
    }

    private static func letters(in key: String) -> Int {
        key.replacingOccurrences(of: "%@", with: "").filter(\.isLetter).count
    }
}
