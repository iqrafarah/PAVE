import Foundation

/// Something Ayla does in the app herself when you ask for it in so many words ("zet het thema op blauw", "open de map
/// Stages", "ga terug"), typed or spoken, so PAVE works hands-free. It is your own instruction, so it is carried out
/// at once; everything else still goes to Ayla.
public enum AylaAppCommand: Equatable, Sendable {
    public enum SettingsPage: String, Sendable {
        case appearance, devices, ayla, privacy
    }

    case settingsPage(SettingsPage)
    case theme(PaveThemeColor)
    case textSize(PaveTextSize)
    case vaultLayout(PaveVaultLayout)
    case voiceText(Bool)
    case chatsInSearch(Bool)
    case vaultFolder(id: String)
    case vaultItem(id: String)
    case back
    case close

    /// A named thing in the vault that can be opened by its name.
    public struct Named: Equatable, Sendable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    /// Only changing something says so afterwards; going somewhere just happens.
    public var changesSomething: Bool {
        switch self {
        case .theme, .textSize, .vaultLayout, .voiceText, .chatsInSearch: true
        case .settingsPage, .vaultFolder, .vaultItem, .back, .close: false
        }
    }

    public static func command(in text: String, folders: [Named] = [], items: [Named] = []) -> AylaAppCommand? {
        let asked = AylaScreenRequest.normalized(text).folding(options: .diacriticInsensitive, locale: nil)
        guard !asked.isEmpty, asked.count <= 120 else { return nil }
        func has(_ pattern: String) -> Bool { AylaScreenRequest.matches(asked, pattern) }
        let isQuestion = has(#"^(wat|welke|welk|waarom|hoe|wanneer|wie|waar|is|staat|heb|kan ik|kun je me vertellen)\b"#)
        let changes = has(#"\b(zet|maak|kies|verander|wijzig|wissel|doe|selecteer|pas|gebruik|neem|stel)\b"#)
        let opens = has(#"\b(open|opent|openen|toon|bekijk|ga naar|naar|kies|selecteer|klik op|tik op|druk op|laat)\b"#)
        let on = has(#"\b(aan|aanzetten|inschakelen|wel)\b"#) && !has(#"\b(uit|uitzetten|uitschakelen|niet)\b"#)
        let off = has(#"\b(uit|uitzetten|uitschakelen|niet)\b"#)

        if has(#"^(ga )?(even )?terug$|^vorige( pagina)?$|^ga een (stap|pagina) terug$"#) { return .back }
        if has(#"^(sluit|sluiten|doe dicht|dicht|klaar|sluit (dit|het|maar|de pagina|het scherm))( maar)?$"#) { return .close }
        guard !isQuestion else { return nil }

        if has(#"\b(tekst bij (het )?praten|tekst bij de stem|ondertiteling|meelezen)\b"#), on || off { return .voiceText(!off) }
        if has(#"\b(vindbaar|iphone-zoeken|iphone zoeken|spotlight)\b"#), on || off { return .chatsInSearch(!off) }

        if let theme = themes.first(where: { has("\\b(?:\($0.words))\\b") })?.theme {
            let onlyColour = has("^(?:(?:het|de|thema|kleur|themakleur|naar|op|in|graag|alsjeblieft) )*(?:\(themes.map(\.words).joined(separator: "|")))$")
            // Short and about the app itself, so "maak een cv met een blauwe kop" stays a question for Ayla.
            let words = asked.split(separator: " ").count
            let aboutTheme = has(#"\b(thema|kleur|kleuren|themakleur|kleurenthema)\b"#)
            let aboutApp = has(#"\b(het|alles|pave|app)\b"#)
            if onlyColour || (aboutTheme && words <= 6) || (changes && (words <= 3 || (aboutApp && words <= 6))) { return .theme(theme) }
        }
        if has(#"\b(tekst|letters|letter|lettergrootte|tekstgrootte)\b"#) {
            if has(#"\b(groot|groter|grote|grotere)\b"#) { return .textSize(.large) }
            if has(#"\b(klein|kleiner|kleine|kleinere)\b"#) { return .textSize(.small) }
            if has(#"\b(standaard|normaal|normale|gewoon|gewone)\b"#) { return .textSize(.standard) }
        }
        if has(#"\b(kluis|kluisweergave|weergave)\b"#) {
            if has(#"\b(lijst|lijstweergave)\b"#) { return .vaultLayout(.list) }
            if has(#"\b(raster|rasterweergave|tegels|grid|blokken)\b"#) { return .vaultLayout(.grid) }
        }

        if let page = pages.first(where: { names, _ in
            has("^(?:(?:de|het|mijn|naar) )*(?:\(names))$") || (opens && has("\\b(?:\(names))\\b"))
        })?.page {
            return .settingsPage(page)
        }

        guard opens else { return nil }
        func mentioned(_ things: [Named]) -> Named? {
            things
                .filter { thing in
                    let name = AylaScreenRequest.normalized(thing.name).folding(options: .diacriticInsensitive, locale: nil)
                    return name.count >= 3 && asked.contains(name)
                }
                .max { $0.name.count < $1.name.count }
        }
        let folder = mentioned(folders)
        let item = mentioned(items)
        if let folder, has(#"\bmap\b"#) || (item?.name.count ?? 0) <= folder.name.count { return .vaultFolder(id: folder.id) }
        if let item { return .vaultItem(id: item.id) }
        return nil
    }

    private static let themes: [(words: String, theme: PaveThemeColor)] = [
        ("groen|groene", .green), ("blauw|blauwe", .blue), ("goud|gouden|geel|gele", .gold), ("roze", .pink),
        ("oranje", .orange), ("paars|paarse", .purple), ("rood|rode", .red), ("limoen|lime", .lime),
    ]

    private static let pages: [(names: String, page: SettingsPage)] = [
        ("weergave|uiterlijk", .appearance),
        ("ingelogde apparaten|apparaten", .devices),
        ("ayla instellingen|instellingen van ayla|geheugen", .ayla),
        ("privacy", .privacy),
    ]
}
