import PAVECore

/// Texts the chat shows. They have no web counterpart yet; agree on them with the web team.
enum AylaMessages {
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
    static let pinFailed = "Vastzetten lukte niet. Probeer het opnieuw."
    static let tooManyFiles = "Je kunt \(AylaAttachment.maxCount) bestanden tegelijk toevoegen."
}
