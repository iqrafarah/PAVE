import Foundation
import Observation
import SwiftUI

/// What the iPhone says about how PAVE looks and talks: the theme colour chosen in Instellingen › Weergave, and whether
/// Ayla's words show as text (Instellingen › Ayla). Kept on the Watch, so it looks right before the iPhone answers.
@Observable
final class WatchPreferences {
    static let shared = WatchPreferences()

    private static let accentKey = "watchAccent"
    private static let voiceTextKey = "watchVoiceText"
    nonisolated private static let languageKey = "watchLanguage"
    /// The language of the iPhone app ("nl", "en", "pap"), so Ayla answers on the wrist in it too.
    nonisolated static var language: String? { UserDefaults.standard.string(forKey: languageKey) }
    /// Dates and numbers in that language; Papiamentu uses the Dutch formats of Curaçao.
    nonisolated static var locale: Locale {
        switch language {
        case "en": Locale(identifier: "en_NL")
        case "pap": Locale(identifier: "nl_CW")
        default: Locale(identifier: "nl_NL")
        }
    }

    /// The language of the iPhone app, kept here too so the Watch's own words draw again when it changes.
    private(set) var languageCode: String?
    /// The theme colour as 0xRRGGBB; nil is PAVE green.
    private(set) var accent: UInt32?
    /// Show what Ayla says as text; off shows only the orb (and the choices she asks).
    private(set) var showsVoiceText: Bool

    private init() {
        let defaults = UserDefaults.standard
        accent = (defaults.object(forKey: Self.accentKey) as? Int).map { UInt32(truncatingIfNeeded: $0) }
        showsVoiceText = defaults.object(forKey: Self.voiceTextKey) as? Bool ?? true
        languageCode = defaults.string(forKey: Self.languageKey)
    }

    /// From the iPhone's message; keys it does not carry leave things as they are.
    func apply(_ message: [String: Any]) {
        let defaults = UserDefaults.standard
        if let language = message["language"] as? String {
            defaults.set(language, forKey: Self.languageKey)
            if languageCode != language { languageCode = language }
        }
        if let shows = message["voiceText"] as? Bool {
            showsVoiceText = shows
            defaults.set(shows, forKey: Self.voiceTextKey)
        }
        if message["accentIsGreen"] as? Bool == true {
            accent = nil
            defaults.removeObject(forKey: Self.accentKey)
        } else if let value = message["accent"] as? Int {
            accent = UInt32(truncatingIfNeeded: value)
            defaults.set(value, forKey: Self.accentKey)
        }
    }

    /// The accent of the Watch: the theme colour, or PAVE green.
    var accentColor: Color {
        accent.map { Color(red: Double(($0 >> 16) & 0xFF) / 255, green: Double(($0 >> 8) & 0xFF) / 255, blue: Double($0 & 0xFF) / 255) } ?? .brandGreen
    }

    /// The orb's seven shades from light to deep; PAVE's own greens, or the theme colour from almost white to dark.
    var orbPalette: [Color] {
        guard accent != nil else { return [.orbShade0, .orbShade1, .orbShade2, .orbShade3, .orbShade4, .orbShade5, .orbShade6] }
        let base = accentColor
        return [
            base.mix(with: .white, by: 0.8), base.mix(with: .white, by: 0.6), base.mix(with: .white, by: 0.4),
            base.mix(with: .white, by: 0.2), base, base.mix(with: .black, by: 0.2), base.mix(with: .black, by: 0.4),
        ]
    }

    /// The shades the aura's pixels use: lighter ones and the accent itself.
    var auraPalette: [Color] {
        let shades = orbPalette
        return [shades[1], shades[2], shades[3], shades[4], accentColor]
    }
}
