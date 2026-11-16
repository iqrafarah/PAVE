import PAVECore

/// Texts the chat shows. They have no web counterpart yet; agree on them with the web team.
enum AylaMessages {
    /// Above Ja and Nee when Ayla offers to add something to the vault, as on the web (AYLA_VAULT_LABEL).
    static let vaultLabel = "Kluis"
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
