import Foundation
import os
import PAVECore

/// The Watch's own words in the language of the iPhone app, with the same table as the iPhone.
nonisolated enum WatchTranslator {
    /// On the main thread the language is read from the preferences, so a view draws again when it changes.
    static func translate(_ text: String) -> String {
        let code = Thread.isMainThread ? MainActor.assumeIsolated { WatchPreferences.shared.languageCode } : WatchPreferences.language
        guard let code, code != "nl", !text.isEmpty else { return text }
        return table(for: code).translate(text)
    }

    private static let tables = OSAllocatedUnfairLock<[String: TranslationTable]>(initialState: [:])

    private static func table(for code: String) -> TranslationTable {
        tables.withLock { tables in
            if let table = tables[code] { return table }
            let table = TranslationTable(localization: code)
            tables[code] = table
            return table
        }
    }
}

extension String {
    /// This Dutch text in the language of the iPhone app, for texts that leave SwiftUI, such as what is spoken.
    nonisolated var translated: String { WatchTranslator.translate(self) }
}
