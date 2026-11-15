import PAVECore

/// Texts the chat shows. They have no web counterpart yet; agree on them with the web team.
enum AylaMessages {
    /// Above Ja and Nee when Ayla offers to add something to the vault, as on the web (AYLA_VAULT_LABEL).
    static let vaultLabel = "Kluis"
    static let attachItem = "Item uit je kluis"
    static let vaultEmpty = "Je kluis is nog leeg"
    static let pickItemTitle = "Kies uit je kluis"
    static let pickItemHint = "Ayla gebruikt wat je kiest in dit gesprek."
    static let allItems = "Alle items"
    static func contextItems(_ count: Int) -> String { "\(count) items uit je kluis" }
    static func askNotAllowedTitle(_ count: Int) -> String {
        count == 1 ? askNotAllowedTitle : "Ayla mag \(count) van deze items nog niet gebruiken"
    }
    static let askAllowAll = "Toestaan en gebruiken"
    static let askWithoutThem = "Gebruiken zonder die items"
    static let conceptReading = "Ayla leest je bestanden…"
    static let conceptFiles = "Bestanden hierbij"
    static let conceptAdded = "Toegevoegd aan je kluis"
    static let conceptTitle = "Bewijs in opbouw"
    static let conceptReady = "Bewijs"
    static let conceptHint = "Vertel verder en Ayla vult het aan."
    static let conceptAdd = "Zet in de kluis"
    static let headHint = "Knik ja of schud nee"
    static let vacancyHint = "Draai je hoofd voor de volgende, knik om te kiezen"
    static let vacancyChoose = "Kies deze"
    static func vacancyPosition(_ index: Int, of count: Int) -> String { "\(index + 1) van \(count)" }
    static func vacancyAsk(_ vacancy: Vacancy) -> String {
        "Vertel meer over \(vacancy.title) bij \(vacancy.company): waarom past die bij mij, en wat mis ik nog?"
    }
    static func photosAdded(_ count: Int, to title: String) -> String {
        count == 1 ? "Ik heb een foto toegevoegd aan \(title)." : "Ik heb \(count) foto's toegevoegd aan \(title)."
    }
    static let headHintVoice = "Zeg het, of knik ja of schud nee"
    static func headAnswer(_ isYes: Bool) -> String { isYes ? "Je knikte: Ja" : "Je schudde: Nee" }
    static let conceptRequestConfirmation = "Bevestiging aanvragen"
    static let conceptUnknown = "nog niet bekend"

    static func conceptFromFiles(logo: Bool, cover: Bool, items: Int) -> String? {
        var parts: [String] = []
        if logo { parts.append("logo") }
        if cover { parts.append("omslag") }
        var text = parts.isEmpty ? "" : "Uit je bestanden: \(parts.joined(separator: " en ")) gevonden."
        if items > 1 { text += (text.isEmpty ? "" : " ") + "Ayla ziet \(items) bewijzen in je bestanden; je kiest in de volgende stap of je ze apart toevoegt." }
        return text.isEmpty ? nil : text
    }

    static func addedToVault(_ title: String?) -> String {
        title.map { "Toegevoegd aan mijn kluis: \($0)." } ?? "Toegevoegd aan mijn kluis."
    }
    static let openVault = "Open je kluis"
    static let openSettings = "Open instellingen"
    static let clearContext = "Niet meer over dit bewijs vragen"
    static let askAboutItem = "Vraag Ayla over dit bewijs"
    static let askNotAllowedTitle = "Ayla mag dit bewijs nog niet gebruiken"
    static let askNotAllowedMessage = "Sta je het toe, dan kan Ayla dit bewijs meenemen in je vragen en zoekopdrachten. Je kunt het altijd weer uitzetten."
    static let askAllow = "Toestaan en vragen"
    static let askWithout = "Vragen zonder toestemming"

    /// "Uit je kluis: stages, diploma's".
    static func usedVault(_ names: [String]) -> String { "Uit je kluis: \(names.joined(separator: ", "))" }
    /// "Over: Eindstage".
    static func about(_ title: String) -> String { "Over: \(title)" }
    static let noConnection = "Ayla is niet bereikbaar. Controleer je internetverbinding en probeer het opnieuw."
    static let signInAgain = "Je sessie is verlopen. Log opnieuw in om met Ayla te praten."
    static let conversationGone = "Dit gesprek bestaat niet meer. Begin een nieuw gesprek."
    static let unavailable = "Ayla kon nu geen antwoord geven. Probeer het zo opnieuw."
    static let notAvailableInDemo = "Ayla werkt alleen als je met je eigen PAVE-account bent ingelogd."
    static let speechNotAllowed = "Geef PAVE toegang tot je microfoon en spraakherkenning in Instellingen om je vraag in te spreken."
    static let speechUnavailable = "Inspreken werkt nu niet. Typ je vraag maar."
    static let voiceNotAllowed = "Geef PAVE toegang tot je microfoon en spraakherkenning in Instellingen om met Ayla te praten."
    static let fileUnreadable = "In dit bestand staat geen tekst die Ayla kan lezen. Probeer een pdf, een foto of een tekstbestand."
    static let chatsUnavailable = "Je chats konden niet worden geladen. Controleer je internetverbinding en probeer het opnieuw."
    static let renameFailed = "De naam kon niet worden aangepast. Probeer het opnieuw."
    static let deleteFailed = "Het gesprek kon niet worden verwijderd. Probeer het opnieuw."
    static let redoFailed = "Dat lukte niet. Controleer je internetverbinding en probeer het opnieuw."
    static let offline = "Je bent offline. Wat je typt blijft staan tot je weer verbinding hebt."
    static let memorySaveFailed = "Opslaan lukte niet. Controleer je internetverbinding en probeer het opnieuw."
    static let memoryForgetFailed = "Wissen lukte niet. Controleer je internetverbinding en probeer het opnieuw."
    static let memoryNotSetUp = "Het geheugen van Ayla staat nog niet aan in PAVE. Zodra het er is, zie je hier alles wat Ayla over je onthoudt."
    static let pasteRefused = "Plakken lukte niet. Sta het toe bij Instellingen › PAVE › Plakken uit andere apps, of voeg het toe als bestand."
    static let pinFailed = "Vastzetten lukte niet. Probeer het opnieuw."
    static let tooManyFiles = "Je kunt \(AylaAttachment.maxCount) bestanden tegelijk toevoegen."
}
