import Foundation

/// Something Ayla remembers about the user, shared by web, iPhone and Watch (`ayla_memories`). Nothing is saved by
/// itself: Ayla suggests a note in her reply (`AylaReply.memory`) and the user keeps it, or writes one themselves.
public struct AylaMemory: Identifiable, Equatable, Sendable {
    public enum Source: String, Sendable {
        /// Suggested by Ayla and kept by the user.
        case ayla
        /// Written by the user.
        case user
    }

    /// Where a note belongs, so "Wat Ayla over je weet" can group them. The same codes as the Ayla function.
    public enum Category: String, CaseIterable, Codable, Sendable {
        case education
        case work
        case goals
        case skills
        case values
        case workStyle
        case interests
        case personal

        /// An unknown or missing code counts as "Over jou".
        public init(code: String?) {
            self = code.flatMap(Category.init(rawValue:)) ?? .personal
        }

        public init(from decoder: any Decoder) throws {
            self.init(code: try? decoder.singleValueContainer().decode(String.self))
        }

        public var title: String {
            switch self {
            case .education: "Opleiding"
            case .work: "Werk en stages"
            case .goals: "Doelen"
            case .skills: "Vaardigheden"
            case .values: "Wat je belangrijk vindt"
            case .workStyle: "Hoe je wilt werken"
            case .interests: "Interesses en hobby's"
            case .personal: "Over jou"
            }
        }
    }

    public static let maxLength = 300

    public var id: String
    public var text: String
    public var category: Category
    public var source: Source
    public var createdAt: Date

    public init(id: String, text: String, category: Category = .personal, source: Source, createdAt: Date) {
        self.id = id
        self.text = text
        self.category = category
        self.source = source
        self.createdAt = createdAt
    }

    /// The text as it is saved: one line, trimmed, at most `maxLength` characters. Nil when nothing is left.
    public static func clean(_ text: String) -> String? {
        let line = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !line.isEmpty else { return nil }
        return String(line.prefix(maxLength))
    }

    /// The same note, whatever the capitals or the full stop at the end.
    public static func isSame(_ a: String, _ b: String) -> Bool {
        func plain(_ text: String) -> String {
            text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        }
        return plain(a) == plain(b)
    }

    /// Small words that say nothing about the person. Keep in sync with STOP_WORDS in the Ayla function.
    static let stopWords: Set<String> = [
        "je", "jij", "jouw", "ik", "mijn", "me", "de", "het", "een", "en", "of", "bij", "als", "aan", "op", "in", "van",
        "voor", "met", "naar", "om", "te", "dat", "die", "dit", "er", "is", "zijn", "ben", "bent", "wil", "wilt", "graag",
        "nu", "ook",
    ]

    /// The words that carry the meaning, without capitals or accents.
    static func meaningfulWords(_ text: String) -> Set<String> {
        let plain = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_NL"))
        let words = plain.lowercased().split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.map(String.init)
        return Set(words.filter { $0.count > 1 && !stopWords.contains($0) })
    }

    /// This note already says what `suggestion` says, also in other words: nearly all of its meaningful words are in it.
    public func covers(_ suggestion: String) -> Bool {
        let words = Self.meaningfulWords(suggestion)
        guard !words.isEmpty else { return true }
        let known = Self.meaningfulWords(text)
        return Double(words.filter(known.contains).count) / Double(words.count) >= 0.75
    }
}

/// What Ayla remembers and whether the user lets her.
public struct AylaMemories: Equatable, Sendable {
    /// Off: Ayla uses none of the notes and suggests nothing. The notes stay until the user deletes them.
    public var isEnabled: Bool
    /// The newest first.
    public var notes: [AylaMemory]

    public init(isEnabled: Bool = true, notes: [AylaMemory] = []) {
        self.isEnabled = isEnabled
        self.notes = notes
    }

    /// The notes per category, in the order of `Category.allCases`, without empty ones.
    public var byCategory: [(category: AylaMemory.Category, notes: [AylaMemory])] {
        AylaMemory.Category.allCases.compactMap { category in
            let inCategory = notes.filter { $0.category == category }
            return inCategory.isEmpty ? nil : (category, inCategory)
        }
    }

    public func contains(_ text: String) -> Bool {
        notes.contains { AylaMemory.isSame($0.text, text) }
    }

    /// Ayla already knows this, maybe in other words.
    public func knows(_ text: String) -> Bool {
        notes.contains { $0.covers(text) }
    }
}
