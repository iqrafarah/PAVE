import Foundation
import os
import PAVECore

/// Turns a Dutch text into the language chosen in Instellingen › Taal, with the table in `Localizable.xcstrings`.
nonisolated enum PaveTranslator {
    /// On the main thread the language is read from the store, so a view that shows a text draws again when it
    /// changes. Elsewhere, such as in a tip, the last chosen language is used.
    static func translate(_ text: String) -> String {
        let language = Thread.isMainThread ? MainActor.assumeIsolated { PaveLanguageStore.shared.language } : PaveLanguageStore.current
        return translate(text, into: language)
    }

    static func translate(_ text: String, into language: PaveLanguage) -> String {
        guard language != .dutch, !text.isEmpty else { return text }
        return table(for: language).translate(text)
    }

    private static let tables = OSAllocatedUnfairLock<[PaveLanguage: TranslationTable]>(initialState: [:])

    private static func table(for language: PaveLanguage) -> TranslationTable {
        tables.withLock { tables in
            if let table = tables[language] { return table }
            let table = TranslationTable(localization: language.rawValue)
            tables[language] = table
            return table
        }
    }
}

extension String {
    /// This Dutch text in the language chosen in Instellingen. Views translate on their own; use this for texts that
    /// leave SwiftUI, such as notifications.
    nonisolated var translated: String { PaveTranslator.translate(self) }
}
