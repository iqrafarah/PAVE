import PAVECore

/// The texts of Instellingen (Figma FEDDIES 1393:5359). Agree on new ones with the web team.
enum SettingsMessages {
    static let account = "Account"
    static let accountSubtitle = "Je naam, foto en gegevens"
    static let general = "Algemeen"
    static let aylaAndPrivacy = "Ayla en privacy"
    static let profilePhoto = "Profielafbeelding"
    static let changePhoto = "Wijzigen"
    static let removePhoto = "Verwijderen"
    static let photoHint = "Kies een foto en schuif hem zo dat je gezicht in de cirkel staat."
    static let photoTitle = "Profielafbeelding"
    static let removePhotoQuestion = "Profielafbeelding verwijderen?"
    static let name = "Hoe Ayla je noemt"
    static let namePrompt = "Je voornaam of roepnaam"
    static let nameHint = "Leeg laten? Dan gebruikt PAVE de voornaam van je school of organisatie."
    static let saveName = "Bewaren"
    static let fullName = "Volledige naam"
    static let email = "E-mailadres"
    static let fromOrganisation = "Komt van je school of organisatie en kun je hier niet aanpassen."
    static let appearance = "Weergave"
    static let language = "Taal"
    static let languageSynced = "Deze keuze volgt je account op al je apparaten."
    static let languageHint = "PAVE verandert meteen van taal. Ayla antwoordt in de taal waarin je haar schrijft. Wat je zelf hebt gemaakt, zoals je chats en je kluis, blijft zoals het is."
    static let themeColor = "Themakleur"
    static let customColorHint = "Kies je eigen kleur"
    static let vaultLayout = "Weergave kluis"
    static let vaultLayoutHint = "Zo opent je kluis. In de kluis kun je even wisselen; de volgende keer opent hij weer zo."
    static let textSize = "Tekstgrootte"
    static let fontStyle = "Lettertype"
    static let fontStyleHint = "Leesbaar is Atkinson Hyperlegible: letters die je minder snel door elkaar haalt. Je keuze blijft op dit toestel."
    static func title(_ style: PaveFontStyle) -> String {
        switch style {
        case .pave: "PAVE"
        case .system: "Systeem"
        case .rounded: "Rond"
        case .serif: "Schreef"
        case .readable: "Leesbaar"
        }
    }
    static let animationsOff = "Animaties uitzetten"
    static let animationsOffHint = "Alles in PAVE blijft stil staan: geen bewegende overgangen, laders of golven. Geldt alleen op dit apparaat."
    static let onThisDeviceOnly = "Je keuzes gelden nu alleen op dit toestel. Zodra PAVE er klaar voor is, gelden ze voor je hele account."
    static let notSetUp = "Je naam en foto aanpassen kan nog niet. Zodra PAVE er klaar voor is, kan het hier."

    static func title(_ layout: PaveVaultLayout) -> String {
        switch layout {
        case .list: "Lijstweergave"
        case .grid: "Rasterweergave"
        }
    }

    static let displayMode = "Licht of donker"
    static let displayAutoHint = "Automatisch volgt de instelling van je apparaat."
    static let displaySynced = "Deze keuze volgt je account, ook op het web."
    static let displayLocal = "Deze keuze geldt alleen op dit apparaat."

    static func title(_ mode: PaveDisplayMode) -> String {
        switch mode {
        case .auto: "Automatisch"
        case .light: "Licht"
        case .dark: "Donker"
        }
    }

    static func title(_ size: PaveTextSize) -> String {
        switch size {
        case .small: "Klein"
        case .standard: "Standaard"
        case .large: "Groot"
        }
    }

    static func title(_ theme: PaveThemeColor) -> String {
        switch theme {
        case .green: "Groen"
        case .blue: "Blauw"
        case .gold: "Goud"
        case .pink: "Roze"
        case .orange: "Oranje"
        case .purple: "Paars"
        case .red: "Rood"
        case .lime: "Limoen"
        case .custom: "Eigen kleur"
        }
    }

    static func message(for error: ProfileError) -> String {
        switch error {
        case .noConnection: "Geen verbinding. Probeer het zo nog een keer."
        case .notSignedIn: "Je bent niet meer ingelogd. Log opnieuw in."
        case .notAllowed: "Dit mag niet met dit account. Log opnieuw in en probeer het nog een keer."
        case .notSetUp: notSetUp
        case .nameTooLong: "Gebruik hooguit \(PaveProfile.maximumNameLength) tekens."
        case .unavailable: "Dat lukte niet. Probeer het later nog een keer."
        }
    }
}
