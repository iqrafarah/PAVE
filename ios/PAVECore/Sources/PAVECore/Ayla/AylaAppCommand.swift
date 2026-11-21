import Foundation

/// Something Ayla does in the app herself when you ask for it in so many words ("zet het thema op blauw", "open de map
/// Stages", "ga terug"), typed or spoken, so PAVE works hands-free. It is your own instruction, so it is carried out
/// at once; everything else still goes to Ayla.
public enum AylaAppCommand: Equatable, Sendable {
    public enum SettingsPage: String, Sendable {
        case appearance, devices, ayla, privacy, retention, archive
    }

    case settingsPage(SettingsPage)
    case theme(PaveThemeColor)
    case textSize(PaveTextSize)
    /// "Groter" or "kleiner": one size up or down from what it is now.
    case textSizeStep(Int)
    case vaultLayout(PaveVaultLayout)
    case displayMode(PaveDisplayMode)
    case voiceText(Bool)
    case chatsInSearch(Bool)
    case vaultFolder(id: String)
    case vaultItem(id: String)
    case back
    case close
    /// "Bewaar deze vacature", "bewaar de tweede": the place in the latest list (0 is the first, -1 the last), or nil for
    /// the one you are looking at.
    case saveVacancy(Int?)
    case openSavedVacancies
    /// "Toon de vacatures": the latest ones Ayla found in this chat.
    case openVacancies
    /// "Open de tweede vacature": its place in the list (0 is the first, -1 the last).
    case openVacancy(Int)

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
        case .theme, .textSize, .textSizeStep, .vaultLayout, .displayMode, .voiceText, .chatsInSearch: true
        case .settingsPage, .vaultFolder, .vaultItem, .back, .close, .openSavedVacancies, .openVacancies, .openVacancy: false
        case .saveVacancy: true
        }
    }

    /// `inSettings`: Instellingen is open, so a bare "blauw" or "privacy" is about what is on screen. Elsewhere a
    /// single word is an answer to Ayla, and only a whole instruction counts.
    public static func command(in text: String, folders: [Named] = [], items: [Named] = [], inSettings: Bool = false) -> AylaAppCommand? {
        let asked = plain(text)
        let words = asked.split(separator: " ").count
        guard words > 0, asked.count <= 120 else { return nil }
        func has(_ pattern: String) -> Bool { AylaScreenRequest.matches(asked, pattern) }
        /// "open X", "ga naar de map X", "laat X zien", "X openen": the thing itself is what is opened.
        func opens(_ name: String) -> Bool {
            // Nothing may follow but a polite word, so "ik ga naar mijn stages kijken" stays a sentence for Ayla.
            let end = "(?: (?:alsjeblieft|aub|graag|even|eens|maar))*$"
            return has("\\b(?:open|opent|toon|bekijk|naar|kies|selecteer|klik op|tik op|druk op) \(fillers)(?:\(name))\(end)")
                || has("\\blaat \(fillers)(?:\(name)) zien\(end)")
                || has("\\b(?:\(name)) \(fillers)(?:openen|bekijken|tonen|open)\(end)")
        }
        func isOnly(_ name: String) -> Bool { has("^\(fillers)(?:\(name))$") }
        func opensSomething() -> Bool {
            has(#"^(?:(?:ayla|hey|hoi|kun je|kan je|wil je) )*(?:open|toon|bekijk|laat|ga naar|naar)\b"#) || has(#"\b(?:openen|bekijken|tonen|zien)$"#)
        }

        if has(#"^(ga )?(even |eens )?(een (stap|pagina) )?terug$|^vorige( pagina)?$"#) { return .back }
        if has(#"^(sluit|sluiten|doe dicht)( (dit|het|maar|de pagina|het scherm|de kluis|instellingen|de instellingen))*$"#) { return .close }
        guard !has(#"^(wat|welke|welk|waarom|hoe|wanneer|wie|waar|is|staat|heb|kan ik|zijn)\b"#) else { return nil }
        // Two things in one sentence ("zet donker aan en open mijn stages") are for Ayla's brain, which does both;
        // here only the first would happen. "Licht of donker" and a name with "en" in it are still one thing.
        // "Open instellingen en zet het thema op goud" is one thing: a setting opens Instellingen itself.
        let afterSettings = asked.replacingOccurrences(of: #"^(?:open|ga naar|naar) (?:(?:de|mijn|je) )?(?:instellingen|settings) en "#, with: "", options: .regularExpression)
        func hasTwo(_ pattern: String) -> Bool { AylaScreenRequest.matches(afterSettings, pattern) }
        if hasTwo(#"\b(en dan|en daarna|daarna|vervolgens|en ook)\b"#) { return nil }
        if hasTwo(#" en (?:(?:ook|dan|graag|even) )*(?:open|toon|zet|maak|ga|kies|sluit|bewaar|verander|wijzig|laat|start|begin|archiveer|verwijder|pin)\b"#) { return nil }

        let changes = has(#"\b(zet|zetten|maak|maken|kies|kiezen|verander|veranderen|wijzig|wijzigen|wissel|doe|selecteer|pas|gebruik|neem|stel)\b"#)
        let off = has(#"\b(uit|uitzetten|uitschakelen|niet)\b"#)
        let on = !off && has(#"\b(aan|aanzetten|inschakelen|wel)\b"#)

        if has(#"\b(tekst bij (het )?praten|tekst bij de stem|ondertiteling|meelezen)\b"#), on || off { return .voiceText(on) }
        if has(#"\b(donkere modus|dark mode|nachtmodus|donker thema)\b"#), words <= 8 { return .displayMode(off ? .light : .dark) }
        if has(#"\b(lichte modus|light mode|licht thema)\b"#), words <= 8 { return .displayMode(off ? .dark : .light) }
        if has(#"^(?:(?:zet|maak|het|de|app|pave|alles|op|graag|alsjeblieft) )*(donker|licht)$"#) {
            return .displayMode(has(#"donker$"#) ? .dark : .light)
        }
        if has(#"\b(licht of donker|weergavemodus)\b.*\bautomatisch\b|\bautomatisch (licht|donker|licht of donker)\b"#) { return .displayMode(.auto) }
        if has(#"\b(vindbaar|iphone-zoeken|iphone zoeken|spotlight)\b"#), on || off { return .chatsInSearch(on) }

        if let theme = themes.first(where: { has("\\b(?:\($0.words))\\b") })?.theme {
            // Short and about the app itself, so "maak een cv met een blauwe kop" stays a question for Ayla.
            let aboutTheme = has(#"\b(thema|themakleur|kleurenthema|kleur van (de app|pave)|kleuren thema)\b"#)
            let aboutApp = has(#"\b(het|alles|pave|app)\b"#)
            let onlyColour = isOnly("(?:(?:thema|kleur|themakleur|naar|op|in) )*(?:\(themes.map(\.words).joined(separator: "|")))")
            if (onlyColour && (inSettings || words > 1)) || (aboutTheme && words <= 10) || (changes && (words <= 3 || (aboutApp && words <= 6))) {
                return .theme(theme)
            }
        }
        if has(#"\b(tekst|letters|letter|lettergrootte|tekstgrootte)\b"#), words <= 8 {
            if has(#"\b(groter|grotere)\b"#) { return .textSizeStep(1) }
            if has(#"\b(kleiner|kleinere)\b"#) { return .textSizeStep(-1) }
            if has(#"\b(groot|grote)\b"#) { return .textSize(.large) }
            if has(#"\b(klein|kleine)\b"#) { return .textSize(.small) }
            if has(#"\b(standaard|normaal|normale|gewoon|gewone)\b"#) { return .textSize(.standard) }
        }
        if has(#"\b(kluis|kluisweergave|weergave)\b"#), words <= 8 {
            if has(#"\b(lijst|lijstweergave)\b"#) { return .vaultLayout(.list) }
            if has(#"\b(raster|rasterweergave|tegels|grid|blokken)\b"#) { return .vaultLayout(.grid) }
        }

        if has(#"\bbewaarde vacatures?\b"#), has(#"^(open|toon|laat|bekijk|ga naar|naar|mijn|wat zijn|welke)\b"#) || words <= 4 {
            return .openSavedVacancies
        }
        let ordinals: [(String, Int)] = [("eerste|1|een", 0), ("tweede|2|twee", 1), ("derde|3|drie", 2), ("vierde|4|vier", 3), ("vijfde|5|vijf", 4), ("laatste", -1)]
        func vacancyPlace() -> Int? {
            ordinals.first(where: { has("\\b(?:de |vacature |nummer )(?:\($0.0))\\b") || has("\\b(?:\($0.0))e? vacature\\b") })?.1
        }
        if has(#"\b(bewaar|bewaren|sla)\b"#), !has(#"\b(kluis|chat|gesprek|bestand|foto)\b"#), words <= 7 {
            if let place = vacancyPlace() { return .saveVacancy(place) }
            if has(#"\b(deze|die|dit|hem|vacature)\b"#) { return .saveVacancy(nil) }
        }
        if has(#"\bvacature\b"#), words <= 7, opensSomething(), let place = vacancyPlace() { return .openVacancy(place) }
        if has(#"\bvacatures\b"#), !has(#"\b(zoek|zoeken|vind|vinden|nieuwe|andere|meer)\b"#), words <= 6, opensSomething() {
            return .openVacancies
        }
        if let page = pages.first(where: { opens($0.names) || (inSettings && isOnly($0.names)) })?.page {
            return .settingsPage(page)
        }

        func mentioned(_ things: [Named], as kind: String) -> Named? {
            things
                .filter { thing in
                    let name = plain(thing.name)
                    guard name.count >= 3 else { return false }
                    return opens("(?:(?:\(kind)) )?" + NSRegularExpression.escapedPattern(for: name))
                }
                .max { $0.name.count < $1.name.count }
        }
        let folder = mentioned(folders, as: "map|de map|mijn map")
        let item = mentioned(items, as: "bewijs|het bewijs|mijn bewijs|bewijsstuk|het bewijsstuk")
        if let folder, has(#"\bmap\b"#) || (item?.name.count ?? 0) <= folder.name.count { return .vaultFolder(id: folder.id) }
        if let item { return .vaultItem(id: item.id) }
        return nil
    }

    /// Lowercase, without punctuation or accents, so "Diploma’s" is found by "diploma's" and "diplomas" alike.
    private static func plain(_ text: String) -> String {
        AylaScreenRequest.normalized(text).folding(options: .diacriticInsensitive, locale: nil)
    }

    /// Small words that may stand between "open" and the thing.
    private static let fillers = "(?:(?:eens|even|ff|me|mij|mijn|m'n|mn|de|het|je|jouw|maar|dan|nu|graag|alsjeblieft|aub|naar|op) )*"

    private static let themes: [(words: String, theme: PaveThemeColor)] = [
        ("groen|groene", .green), ("blauw|blauwe", .blue), ("goud|gouden|geel|gele", .gold), ("roze", .pink),
        ("oranje", .orange), ("paars|paarse", .purple), ("rood|rode", .red), ("limoen|lime", .lime),
    ]

    private static let pages: [(names: String, page: SettingsPage)] = [
        ("weergave|uiterlijk", .appearance),
        ("ingelogde apparaten|apparaten", .devices),
        ("ayla instellingen|instellingen van ayla|geheugen", .ayla),
        ("privacy", .privacy),
        ("gegevens bewaren|verval", .retention),
        ("archief|mijn archief", .archive),
    ]
}
