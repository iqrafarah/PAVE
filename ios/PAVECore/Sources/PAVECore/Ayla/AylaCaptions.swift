import Foundation

/// Captions for Ayla's voice: the sentence she is saying. The voice does not report timings, so the place in the text
/// is estimated from how long she has been talking.
public enum AylaCaptions {
    /// The sentences of `text`, each with the punctuation that ends it.
    public static func sentences(in text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        var previous: Character?
        for character in text {
            if character.isWhitespace, let previous, ".!?".contains(previous) {
                let sentence = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty { sentences.append(sentence) }
                current = ""
            } else {
                current.append(character)
            }
            previous = character
        }
        let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { sentences.append(last) }
        return sentences
    }

    /// The sentence that holds character `position` of `text`; the last one once she is past the end.
    public static func sentence(in text: String, at position: Int) -> String? {
        let sentences = sentences(in: text)
        var end = 0
        for sentence in sentences {
            end += sentence.count + 1
            if position < end { return sentence }
        }
        return sentences.last
    }
}
