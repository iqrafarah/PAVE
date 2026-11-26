import Foundation
import Observation
import os

/// The languages of PAVE. Dutch is the source: every text in the code is Dutch and the other languages translate it
/// in `Localizable.xcstrings`.
nonisolated enum PaveLanguage: String, CaseIterable, Identifiable, Sendable {
    case dutch = "nl"
    case english = "en"
    case papiamentu = "pap"

    var id: String { rawValue }

    /// Each language by its own name, so you can find yours even when you cannot read the one PAVE is in.
    var nativeName: String {
        switch self {
        case .dutch: "Nederlands"
        case .english: "English"
        case .papiamentu: "Papiamentu"
        }
    }

    /// The flag beside the name. Papiamentu gets Curaçao's, whose spelling PAVE uses.
    var flag: String {
        switch self {
        case .dutch: "🇳🇱"
        case .english: "🇬🇧"
        case .papiamentu: "🇨🇼"
        }
    }

    /// Dates and numbers. iOS has no Papiamentu formats, so Papiamentu uses the Dutch ones of Curaçao.
    var locale: Locale {
        switch self {
        case .dutch: Locale(identifier: "nl_NL")
        case .english: Locale(identifier: "en_NL")
        case .papiamentu: Locale(identifier: "nl_CW")
        }
    }

    /// The language of the device when PAVE has it, otherwise Dutch.
    static var device: PaveLanguage {
        for identifier in Locale.preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
            if let language = PaveLanguage(rawValue: code) { return language }
        }
        return .dutch
    }
}

/// The language chosen in Instellingen › Taal. Views that show text read it while they draw, so every text changes
/// at once when you pick another language.
@Observable
final class PaveLanguageStore {
    static let shared = PaveLanguageStore()
    nonisolated static let key = "pave.language"
    /// The same language for code off the main thread, which cannot read the store.
    nonisolated static var current: PaveLanguage { latest.withLock { $0 } }
    nonisolated private static let latest = OSAllocatedUnfairLock(initialState: stored(in: .standard))

    nonisolated private static func stored(in defaults: UserDefaults) -> PaveLanguage {
        defaults.string(forKey: key).flatMap(PaveLanguage.init(rawValue:)) ?? .device
    }

    private(set) var language: PaveLanguage
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = Self.stored(in: defaults)
    }

    func select(_ language: PaveLanguage) {
        guard language != self.language else { return }
        defaults.set(language.rawValue, forKey: Self.key)
        // iOS's own texts (share sheet, photo picker) follow from the next launch; it has no Papiamentu, so Dutch.
        defaults.set([language.rawValue, PaveLanguage.dutch.rawValue], forKey: "AppleLanguages")
        self.language = language
        Self.latest.withLock { $0 = language }
    }
}
