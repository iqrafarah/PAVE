import Foundation
import Testing
import PAVECore
@testable import PAVE

/// Localization testing. PAVE's texts are Dutch in the code and `Localizable.xcstrings` translates them into English
/// and Papiamentu (see `PaveTranslator`). These tests check three things:
/// - the catalog: every text has every language, and a translation keeps the values (`%@`) and spacing of the Dutch;
/// - the app: the built app carries every language, and the translator finds every text in it;
/// - the code: every Dutch text on a screen, filled in the way it is shown, comes out in English.
struct LocalizationTests {
    // MARK: Catalog

    @Test func theCatalogIsDutchWithEveryLanguageOfTheApp() throws {
        let catalog = try Catalog.load()
        #expect(catalog.sourceLanguage == PaveLanguage.dutch.rawValue)
        let languages = Set(catalog.strings.values.flatMap { $0.localizations?.keys.map { $0 } ?? [] })
        #expect(languages.isSuperset(of: Catalog.translations.map(\.rawValue)))
    }

    @Test func everyTextHasEveryLanguage() throws {
        var problems: [String] = []
        for (key, entry) in try Catalog.load().translated {
            for language in Catalog.translations {
                guard let unit = entry.localizations?[language.rawValue]?.stringUnit else {
                    problems.append("\(language.rawValue) ontbreekt: \(key.debugDescription)")
                    continue
                }
                if unit.state != "translated" { problems.append("\(language.rawValue) is \(unit.state): \(key.debugDescription)") }
                if unit.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !key.trimmingCharacters(in: .whitespaces).isEmpty {
                    problems.append("\(language.rawValue) is leeg: \(key.debugDescription)")
                }
            }
        }
        #expect(problems.isEmpty, "\(problems.count) teksten:\n\(problems.sorted().joined(separator: "\n"))")
    }

    /// A translation with fewer or other values than the Dutch would show the wrong value, or none.
    @Test func translationsKeepTheValuesOfTheDutch() throws {
        var problems: [String] = []
        for (key, entry) in try Catalog.load().translated {
            for language in Catalog.translations {
                guard let value = entry.value(language) else { continue }
                if Catalog.placeholders(in: value) != Catalog.placeholders(in: key) {
                    problems.append("\(language.rawValue): \(key.debugDescription) → \(value.debugDescription)")
                }
            }
        }
        #expect(problems.isEmpty, "\(problems.count) teksten:\n\(problems.sorted().joined(separator: "\n"))")
    }

    /// Texts such as " op %@" are glued to another text: a lost space glues two words together.
    @Test func translationsKeepTheSpacingOfTheDutch() throws {
        var problems: [String] = []
        for (key, entry) in try Catalog.load().translated {
            for language in Catalog.translations {
                guard let value = entry.value(language) else { continue }
                let same = (key.first?.isWhitespace == value.first?.isWhitespace)
                    && (key.last?.isWhitespace == value.last?.isWhitespace)
                    && key.filter(\.isNewline).count == value.filter(\.isNewline).count
                if !same { problems.append("\(language.rawValue): \(key.debugDescription) → \(value.debugDescription)") }
            }
        }
        #expect(problems.isEmpty, "\(problems.count) teksten:\n\(problems.sorted().joined(separator: "\n"))")
    }

    /// A Papiamentu text that is the English one was copied, not translated.
    @Test func papiamentuIsNotCopiedFromEnglish() throws {
        let copied = try Catalog.load().translated.compactMap { key, entry -> String? in
            guard let english = entry.value(.english), let papiamentu = entry.value(.papiamentu),
                  english == papiamentu, english != key, english.filter(\.isLetter).count > 12 else { return nil }
            return key.debugDescription
        }
        #expect(copied.isEmpty, "\(copied.count) teksten:\n\(copied.sorted().joined(separator: "\n"))")
    }

    // MARK: App

    @Test(arguments: Catalog.translations)
    func theAppCarriesEveryLanguage(_ language: PaveLanguage) throws {
        let url = try #require(Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language.rawValue))
        let table = try #require(NSDictionary(contentsOf: url) as? [String: String])
        let catalog = try Catalog.load().translated
        let missing = catalog.keys.filter { table[$0] == nil }
        #expect(missing.isEmpty, "\(missing.count) teksten niet in de app:\n\(missing.sorted().joined(separator: "\n"))")
    }

    /// Every text of the catalog, with names in its values, comes out as its translation, and not as the translation
    /// of another text that happens to fit.
    @Test(arguments: Catalog.translations)
    func theTranslatorFindsEveryText(_ language: PaveLanguage) throws {
        var problems: [String] = []
        for (key, entry) in try Catalog.load().translated {
            guard let translation = entry.value(language) else { continue }
            let count = key.components(separatedBy: "%@").count - 1
            // A key of only values, like "%@ · %@", is only used as it is: the translator does not fill it in.
            guard count == 0 || key.replacingOccurrences(of: "%@", with: "").filter(\.isLetter).count >= 3 else { continue }
            let values = Array(Catalog.sampleNames.prefix(count))
            let text = TranslationTable.fill(key, with: values)
            let expected = TranslationTable.fill(translation, with: values)
            let result = PaveTranslator.translate(text, into: language)
            if result != expected { problems.append("\(text.debugDescription) → \(result.debugDescription), verwacht \(expected.debugDescription)") }
        }
        #expect(problems.isEmpty, "\(problems.count) teksten:\n\(problems.sorted().joined(separator: "\n"))")
    }

    @Test func datesFollowTheLanguage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 12))!
        func month(_ language: PaveLanguage) -> String {
            var style = Date.FormatStyle(date: .long, time: .omitted).locale(language.locale)
            style.timeZone = calendar.timeZone
            return date.formatted(style)
        }
        #expect(month(.dutch).contains("november"))
        #expect(month(.english).contains("November"))
        // iOS has no Papiamentu dates: Papiamentu uses the Dutch of Curaçao.
        #expect(month(.papiamentu).contains("november"))
    }

    // MARK: Code

    /// Reads every text in the code the way it ends up on screen: a `\(…)` that picks between texts (`a ? "x" : "y"`)
    /// is tried with each of them, any other value with a short name. Each must come out in English. A text that only
    /// partly translates, such as "Tot 3 juni · nog niet bekeken" becoming "Until 3 June · nog niet bekeken", fails too.
    @Test func everyTextInTheCodeIsTranslated() throws {
        let catalog = try Catalog.load()
        let sameInEnglish = Set(catalog.translated.compactMap { key, entry in entry.value(.english) == key ? key : nil })
        var problems: [String] = []
        for file in try SourceText.files() {
            for found in SourceText(file: file).texts() where !SourceText.untranslatable.contains(found.literal.key) {
                if sameInEnglish.contains(found.literal.key) { continue }
                for text in found.literal.renderings() {
                    let english = PaveTranslator.translate(text, into: .english)
                    let dutchLeft = found.literal.dutchParts.first { english.contains($0) && !sameInEnglish.contains($0) }
                    if english == text || dutchLeft != nil {
                        problems.append("\(found.place): \(text.debugDescription)" + (dutchLeft.map { " (blijft Nederlands: \($0.debugDescription))" } ?? ""))
                        break
                    }
                }
            }
        }
        // A text with fewer than 3 letters of its own, such as "\(a) op \(b)", is never filled in by the translator:
        // write it as `PaveTranslator.format("%@ op %@", a, b)`.
        #expect(problems.isEmpty, "\(problems.count) teksten niet vertaald:\n\(problems.joined(separator: "\n"))")
    }
}

// MARK: - Catalog

nonisolated private struct Catalog: Decodable {
    struct Entry: Decodable {
        struct Localization: Decodable {
            struct Unit: Decodable {
                var state: String
                var value: String
            }

            var stringUnit: Unit?
        }

        var localizations: [String: Localization]?

        func value(_ language: PaveLanguage) -> String? { localizations?[language.rawValue]?.stringUnit?.value }
    }

    var sourceLanguage: String
    var strings: [String: Entry]

    static let translations: [PaveLanguage] = PaveLanguage.allCases.filter { $0 != .dutch }
    /// Names that are no text of PAVE themselves, to put in the `%@`s.
    static let sampleNames = ["Kade", "Jumbo", "Lisa", "OGD", "Eindhoven", "Ravi"]

    static let url = SourceText.ios.appending(path: "PAVE/Resources/Localizable.xcstrings")

    static func load() throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }

    /// The texts that are translated. Entries with only a Dutch format, such as "%@ %@", are left out.
    var translated: [String: Entry] {
        strings.filter { _, entry in
            entry.localizations?.keys.contains { $0 != PaveLanguage.dutch.rawValue } ?? false
        }
    }

    /// The values in a text, such as `%@` or `%lld`, in any order: `%2$@` counts as `%@`.
    static func placeholders(in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(@|l{0,2}[du]|\.?\d*f)"#)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } }
            .sorted()
    }
}

// MARK: - Code

/// The Dutch texts in a Swift file: those given to a SwiftUI view such as `Text("…")` or `Button("…")`, those with
/// `.translated` after them, and those in a `…Messages.swift` file.
nonisolated private struct SourceText {
    static let ios = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// Texts that are the same in every language: names, and examples of what to type.
    static let untranslatable: Set<String> = [
        "PAVE", "eduID", "Ayla", "Aa", "OK", "xxxx-xxxx-xxxx-xxxx", "naam@icloud.com", "naam@voorbeeld.nl",
        // An instruction for Ayla, not a text on screen.
        "Dit is een korte reactie op een bijbaan, geen cv: twee korte zinnen in de ik-vorm over waarom ik deze bijbaan wil en wat ik meebreng.",
    ]

    static func files() throws -> [URL] {
        let folders = ["PAVE", "PAVECore/Sources/PAVECore/Auth"]
        return folders.flatMap { folder -> [URL] in
            let enumerator = FileManager.default.enumerator(at: ios.appending(path: folder), includingPropertiesForKeys: nil)
            return (enumerator?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
        }
        .sorted { $0.path < $1.path }
    }

    /// Views that show the text they are given, translated by `PaveLocalizedViews`.
    private static let views = [
        "Text", "Button", "Label", "Toggle", "TextField", "SecureField", "Picker", "Menu", "Link", "Section",
        "LabeledContent", "ContentUnavailableView", "SupportText", "navigationTitle", "accessibilityLabel",
        "accessibilityHint", "accessibilityValue", "confirmationDialog", "alert", "help",
    ]

    /// A string literal. Each `\(…)` in it is a `Value`: the texts it picks between, or any value.
    struct Literal {
        enum Part {
            case text(String)
            case value(options: [Literal], isOpen: Bool)
        }

        var parts: [Part] = []

        /// The text as it is in the catalog, with `%@` for each value.
        var key: String {
            parts.map { if case .text(let text) = $0 { text } else { "%@" } }.joined()
        }

        /// The text filled in with each choice of its values, at most 24.
        func renderings() -> [String] {
            var results = [""]
            for part in parts {
                let choices: [String] = switch part {
                case .text(let text): [text]
                case .value(let options, let isOpen): options.flatMap { $0.renderings() } + (isOpen ? ["Kade"] : [])
                }
                results = Array(results.flatMap { result in choices.map { result + $0 } }.prefix(24))
            }
            return results
        }

        /// The texts it picks between of two words or more, which would show in Dutch if the translator only
        /// translated the text around them.
        var dutchParts: [String] {
            parts.flatMap { part -> [String] in
                guard case .value(let options, _) = part else { return [] }
                return options.flatMap { option in
                    option.renderings().map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
                        .filter { $0.split(separator: " ").filter { $0.contains(where: \.isLetter) }.count >= 2 }
                    + option.dutchParts
                }
            }
        }
    }

    struct Found {
        var place: String
        var literal: Literal
    }

    let name: String
    let isMessages: Bool
    private let characters: [Character]

    init(file: URL) {
        name = file.path.replacingOccurrences(of: Self.ios.path + "/", with: "")
        isMessages = file.lastPathComponent.hasSuffix("Messages.swift")
        characters = Array((try? String(contentsOf: file, encoding: .utf8)) ?? "")
    }

    func texts() -> [Found] {
        var found: [Found] = []
        var index = 0
        var line = 1
        while index < characters.count {
            let character = characters[index]
            if character.isNewline { line += 1 }
            if starts(with: "//", at: index) {
                index = skip(to: "\n", from: index)
            } else if starts(with: "/*", at: index) {
                line += lines(from: index, to: skip(to: "*/", from: index + 2))
                index = skip(to: "*/", from: index + 2) + 2
            } else if starts(with: "\"\"\"", at: index) {
                let end = skip(to: "\"\"\"", from: index + 3) + 3
                line += lines(from: index, to: end)
                index = end
            } else if starts(with: "#\"", at: index) {
                index = skip(to: "\"#", from: index + 2) + 2
            } else if character == "\"" {
                let start = index
                let (literal, end) = parse(from: index + 1)
                if shows(literalFrom: start, to: end, literal) {
                    found.append(Found(place: "\(name):\(line)", literal: literal))
                }
                line += lines(from: start, to: end)
                index = end
            } else {
                index += 1
            }
        }
        return found
    }

    /// Whether the literal is a text that someone reads, not a name in the code such as "chevron.right".
    private func shows(literalFrom start: Int, to end: Int, _ literal: Literal) -> Bool {
        let words = literal.key.replacingOccurrences(of: "%@", with: "")
        guard words.filter(\.isLetter).count >= 2 else { return false }
        let before = String(characters[max(0, start - 60)..<start]).trimmingCharacters(in: .whitespacesAndNewlines)
        let isShown = Self.views.contains { view in
            guard before.hasSuffix(view + "(") else { return false }
            let previous = before.dropLast(view.count + 1).last
            return previous.map { !$0.isLetter && !$0.isNumber } ?? true
        }
        if isShown { return true }
        if starts(with: ".translated", at: end) { return true }
        guard isMessages else { return false }
        // A piece glued to another text, such as " en " or "Bewijs: ", is checked as part of the whole.
        let key = literal.key
        if key.first?.isWhitespace == true || key.last?.isWhitespace == true { return false }
        // In a messages file every sentence is a text; a single word only when it reads like one ("Annuleer").
        return words.contains(" ") || (words.first?.isUppercase == true && words.allSatisfy { $0.isLetter || $0 == "-" || $0 == "…" })
    }

    /// Reads a literal from just after its opening quote; returns it and the index just after its closing quote.
    private func parse(from start: Int) -> (Literal, Int) {
        var literal = Literal()
        var text = ""
        var index = start
        func flush() {
            if !text.isEmpty { literal.parts.append(.text(text)); text = "" }
        }
        while index < characters.count, characters[index] != "\"" {
            guard characters[index] == "\\", index + 1 < characters.count else {
                text.append(characters[index])
                index += 1
                continue
            }
            let escaped = characters[index + 1]
            switch escaped {
            case "(":
                flush()
                var depth = 1
                var options: [Literal] = []
                var expression = ""
                var cursor = index + 2
                while cursor < characters.count, depth > 0 {
                    let character = characters[cursor]
                    if character == "\"" {
                        let (inner, end) = parse(from: cursor + 1)
                        let innerKey = inner.key
                        if innerKey.isEmpty || innerKey.contains(where: \.isLetter) { options.append(inner) }
                        expression += "\"\""
                        cursor = end
                        continue
                    }
                    if character == "(" { depth += 1 }
                    if character == ")" { depth -= 1 }
                    if depth > 0 { expression.append(character) }
                    cursor += 1
                }
                // Only a choice (`a ? "x" : "y"`, `name ?? "iemand"`) shows one of its texts; anything else, such as
                // a call that takes a text, shows a value of its own.
                // After `??` an empty text only stands in for a missing value, such as `titles.first ?? ""`.
                let picks = expression.contains(" ? ") || expression.contains("??")
                let fallback = expression.contains("??")
                if fallback { options.removeAll { $0.key.isEmpty } }
                literal.parts.append(.value(options: picks ? options : [], isOpen: !picks || options.isEmpty || fallback))
                index = cursor
                continue
            case "u":
                let close = skip(to: "}", from: index)
                let hex = String(characters[(index + 3)..<close])
                if let scalar = UInt32(hex, radix: 16).flatMap(Unicode.Scalar.init) { text.unicodeScalars.append(scalar) }
                index = close + 1
                continue
            case "n": text.append("\n")
            case "t": text.append("\t")
            case "0": text.append("\0")
            default: text.append(escaped)
            }
            index += 2
        }
        flush()
        return (literal, index + 1)
    }

    private func starts(with prefix: String, at index: Int) -> Bool {
        let prefix = Array(prefix)
        guard index + prefix.count <= characters.count else { return false }
        return Array(characters[index..<(index + prefix.count)]) == prefix
    }

    private func skip(to marker: String, from index: Int) -> Int {
        var cursor = index
        while cursor < characters.count, !starts(with: marker, at: cursor) { cursor += 1 }
        return cursor
    }

    private func lines(from start: Int, to end: Int) -> Int {
        characters[start..<min(end, characters.count)].filter(\.isNewline).count
    }
}
