import Foundation
import PAVECore

/// Texts the chat shows. They have no web counterpart yet; agree on them with the web team.
enum AylaMessages {
    /// Above Ja and Nee when Ayla offers to add something to the vault, as on the web (AYLA_VAULT_LABEL).
    static let thinking = "Ayla denkt na…"
    /// On one line where "Ayla denkt na…" stands, so a long search is shortened in the middle.
    static func activity(_ activity: AylaActivity) -> String {
        switch activity {
        case .searchingVacancies(let what, let place, let also):
            let terms = also.map { "\(what) en \($0)" } ?? what
            return place.isEmpty ? "Ayla zoekt vacatures: \(terms)…" : "Ayla zoekt vacatures: \(terms) in \(place)…"
        case .comparingVacancies(let count, let withVault, let chosen):
            let vacancies = count == 1 ? "1 vacature" : "\(count) vacatures"
            guard withVault else { return "Ayla bekijkt \(vacancies)…" }
            if let chosen, chosen > 0 { return "Ayla vergelijkt \(vacancies) met wat je koos…" }
            return "Ayla vergelijkt \(vacancies) met je kluis…"
        case .continuing:
            return "Ayla gaat verder…"
        }
    }
    // What the app says when something Ayla set out to do could not be done, or was done after your Ja.
    static func actionNoFolder(_ name: String) -> String { "Ik kon de map \(name) niet vinden." }
    static func actionNoItem(_ name: String) -> String { "Ik kon \(name) niet vinden in je kluis." }
    static func actionNoChat(_ name: String) -> String { "Ik kon geen gesprek vinden over \(name)." }
    static let actionNoCurrentChat = "Dit gesprek staat nog niet in je lijst, dus dat lukt nu nog niet. Probeer het zo opnieuw."
    static let actionUnknownValue = "Dat kon ik niet instellen: die keuze ken ik niet."
    static let actionUnavailable = "Dat lukt nu niet."
    static func actionFolderExists(_ name: String) -> String { "De map \(name) bestond al. Ik open hem." }
    static func actionDeletedEvidence(_ title: String) -> String { "Ik heb \(title) uit je kluis verwijderd." }
    static let actionDeletedChat = "Ik heb het gesprek verwijderd."
    static let actionForgotAll = "Ik heb alles vergeten wat ik over je onthield."
    static let actionSignsOut = "Ik log je uit."
    static let actionDone = "Gedaan."
    static let actionCouldNotContinue = "Verder gaan lukte nu niet. Probeer het zo opnieuw."
    static func actionAllowed(_ title: String) -> String { "Ik mag \(title) nu bekijken en gebruiken." }
    static let actionsBusy = "Ayla doet dit voor je"
    static let actionsDone = "Ayla deed dit voor je"
    static func actionState(_ state: AylaActionStep.State) -> String {
        switch state {
        case .waiting: "nog niet gedaan"
        case .running: "bezig"
        case .done: "gedaan"
        case .failed: "niet gelukt"
        }
    }
    /// For the Lock Screen and the Dynamic Island: how far she is, and what kind of thing she does, without names.
    static func voiceStep(_ step: Int, of total: Int) -> String { total == 1 ? "Doet iets in PAVE" : "Stap \(step) van \(total)" }
    static func voiceNote(_ activity: AylaActivity) -> String {
        switch activity {
        case .searchingVacancies: "Zoekt vacatures"
        case .comparingVacancies: "Vergelijkt vacatures"
        case .continuing: "Gaat verder"
        }
    }
    static let voiceListening = "Ayla luistert…"
    static let voiceSpeaking = "Ayla praat"
    static let voiceMuted = "Je microfoon staat uit"
    static let voiceHolds = "Ayla wacht tot je klaar bent"
    static let voiceStarting = "Microfoon aanzetten…"
    /// What she says when you want to choose the items yourself and the picker opens.
    static let chooseYourself = "Kies maar. Ik gebruik alleen wat je kiest."
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
    static let siriGoOn = "Zeg \"Praat met Ayla in PAVE\" om verder te gaan."
    static let siriSignInFirst = "Log eerst in bij PAVE, dan kan Ayla je vragen beantwoorden."
    static let siriUnavailable = "Ayla is er nu even niet. Probeer het straks nog eens in PAVE."
    static let siriFailed = "Ayla kon nu geen antwoord geven. Probeer het zo nog eens."
    static let vacancyHint = "Draai je hoofd voor de volgende, knik om te kiezen"
    static let vacancyChoose = "Kies deze"
    static func vacancyPosition(_ index: Int, of count: Int) -> String { "\(index + 1) van \(count)" }
    static let vacancySave = "Bewaren"
    static let vacancySavedLabel = "Bewaard"
    static let vacancyOpen = "Lees de hele vacature"
    /// What you say after "Kies zelf": the items are sent along, these words say what they are for.
    static func useChosen(_ count: Int) -> String {
        count == 1 ? "Gebruik het item dat ik koos." : "Gebruik de \(count) gegevens die ik koos."
    }
    static func vacancySearchedFor(_ search: VacancySearch) -> String {
        let terms = search.also.map { "\(search.what) en \($0)" } ?? search.what
        return search.where.isEmpty ? "Gezocht op: \(terms)" : "Gezocht op: \(terms) in \(search.where)"
    }
    static let vacancyNoData = "Zonder je kluis"
    static func vacancyChosenData(_ count: Int) -> String {
        count == 1 ? "Met 1 gekozen item" : "Met \(count) gekozen gegevens"
    }
    static let vacancyChooseData = "Kies"
    static let vacancyChangeData = "Wijzig"
    /// "2 van 3 vaardigheden passen": of the skills Ayla found in the piece of text she saw.
    static func vacancyFitCount(_ fits: Int, of total: Int) -> String {
        total == 1 ? (fits == 1 ? "De vaardigheid die Ayla vond past" : "De vaardigheid die Ayla vond mis je nog") : "\(fits) van \(total) vaardigheden passen"
    }
    static func actionsSummary(done: Int, failed: Int) -> String {
        let did = done == 1 ? "1 ding gedaan" : "\(done) dingen gedaan"
        guard failed > 0 else { return did }
        return done == 0 ? (failed == 1 ? "Dat lukte niet" : "\(failed) dingen lukten niet") : "\(did), \(failed) niet gelukt"
    }
    /// "Geplaatst op 20 november", from the day the source gives ("2026-11-20"); nil when that is not a day.
    static func vacancyPosted(_ day: String) -> String? {
        guard let date = try? Date(day, strategy: .iso8601.year().month().day()) else { return nil }
        return "Geplaatst op \(date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "nl_NL"))))"
    }
    static let vacancyTitle = "Vacature"
    static let vacancyFromText = "Uit de vacaturetekst"
    static func vacancyTextNote(_ source: Vacancy.Source) -> String {
        switch source {
        case .web: "Een stukje van de pagina waar Ayla deze vacature vond. Controleer de hele vacature op die site."
        case .jooble: "Een stukje van de tekst, zoals Jooble het geeft. De hele vacature lees je bij de werkgever."
        default: "Een stukje van de tekst, zoals Adzuna het geeft. De hele vacature lees je bij de werkgever."
        }
    }
    /// Where the vacancies come from, under the list and the vacancy.
    static func vacancySource(_ source: Vacancy.Source) -> String? {
        switch source {
        case .adzuna: "Vacatures via Adzuna"
        case .jooble: "Vacatures via Jooble"
        case .web: "Gevonden op internet"
        case .example: "Voorbeeldvacature"
        default: nil
        }
    }
    static let vacancyNoMatch = "Ayla heeft deze vacature nog niet met je kluis vergeleken. Vraag het haar hieronder."
    static let vacancyAskButton = "Vraag Ayla"
    static let vacancyFits = "Past bij jou"
    static let vacancyMissing = "Wat je nog mist"
    static let vacancyMatchNote = "Ayla vergeleek je kluis met een stukje van de vacaturetekst. Het is een inschatting, geen oordeel."
    static let vacancyFound = "Gevonden"
    static let vacancySavedTab = "Bewaard"
    static let vacancySavedEmptyTitle = "Nog niets bewaard"
    static let vacancySavedEmpty = "Tik op Bewaren bij een vacature om hem hier terug te vinden, ook op je andere apparaten."
    static let vacancyFoundEmptyTitle = "Nog geen vacatures"
    static let vacancyFoundEmpty = "Vraag Ayla hieronder bijvoorbeeld: zoek vacatures die bij me passen."
    static let vacancySaved = "Vacature bewaard"
    static let vacancyUnsaved = "Niet meer bewaard"
    static let vacancySaveFailed = "Bewaren lukte niet. Probeer het opnieuw."
    static let vacancyUnsaveFailed = "Dat lukte niet. Probeer het opnieuw."
    static let vacancySavedLoadFailed = "Je bewaarde vacatures konden niet worden geladen."
    static func vacancyGapAsk(_ skill: String, for vacancy: Vacancy) -> String {
        "Hoe kan ik \(skill) halen voor \(vacancy.title) bij \(vacancy.company)?"
    }
    static func vacancyAsk(_ vacancy: Vacancy) -> String {
        "Vertel meer over \(vacancy.title) bij \(vacancy.company): waarom past die bij mij, en wat mis ik nog?"
    }
    static func photosAdded(_ count: Int, to title: String) -> String {
        count == 1 ? "Ik heb een foto toegevoegd aan \(title)." : "Ik heb \(count) foto's toegevoegd aan \(title)."
    }
    static let headHintVoice = "Zeg het, of knik ja of schud nee"
    static func headAnswer(_ isYes: Bool) -> String { isYes ? "Je knikte: Ja" : "Je schudde: Nee" }
    static func yesNoAnswer(_ isYes: Bool, byHead: Bool) -> String {
        byHead ? headAnswer(isYes) : isYes ? "Je koos: Ja" : "Je koos: Nee"
    }
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
    static let archiveFailed = "Archiveren lukte niet. Probeer het opnieuw."
    static let unarchiveFailed = "Terugzetten lukte niet. Probeer het opnieuw."
    static let expiryFailed = "Het verval aanpassen lukte niet. Probeer het opnieuw."

    // Web aylaMessages.ts: AYLA_DISCLAIMER, projects and locked chats.
    static let disclaimer = "Ayla is AI en kan fouten maken."
    static let panelResize = "Breedte van de chatlijst aanpassen"
    static let projects = "Projecten"
    static let newProject = "Nieuw project"
    static let projectNameLabel = "Naam van het project"
    static let projectNamePlaceholder = "Bijvoorbeeld: Stage zoeken"
    static let projectInstructions = "Instructies voor Ayla"
    static let projectInstructionsHint = "Ayla volgt dit in elke chat binnen dit project, bijvoorbeeld waar het over gaat of hoe ze moet antwoorden."
    static let projectInstructionsPlaceholder = "Bijvoorbeeld: Help me met stage zoeken in de zorg. Antwoord kort en in simpele taal."
    static let projectEdit = "Project aanpassen"
    static let projectCreate = "Project maken"
    static let projectSettings = "Projectinstellingen"
    static let projectNoInstructions = "Nog geen instructies. Kies Aanpassen om Ayla te vertellen waar dit project over gaat."
    static let projectDeleteQuestion = "Project verwijderen?"
    static let projectDeleteBody = "Je chats blijven bestaan, ze horen alleen niet meer bij een project."
    static let projectDelete = "Project verwijderen"
    static let projectChats = "Chats in dit project"
    static let projectNoChats = "Nog geen chats in dit project. Stel hieronder je eerste vraag."
    static let projectNewChat = "Nieuwe chat in project"
    static func projectChip(_ name: String) -> String { "Nieuwe chat in \(name)" }
    static let projectFailed = "Het project kon niet worden opgeslagen. Probeer het opnieuw."
    static func movedToProject(_ name: String) -> String { "Chat verplaatst naar \(name)" }
    static let removedFromProject = "Chat uit het project gehaald"
    static let moveFailed = "De chat kon niet worden verplaatst. Probeer het opnieuw."
    static let moveToProject = "Naar project verplaatsen"
    static let removeFromProject = "Uit project halen"
    static let moveEmpty = "Je hebt nog geen projecten. Maak er een met de + bij Projecten."
    static let lockMenu = "Chat vergrendelen"
    static let unlockMenu = "Ontgrendelen"
    static let lockQuestion = "Deze chat vergrendelen?"
    static let lockBody = "De chat staat dan alleen nog bij Vergrendelde chats. Je opent hem met je pincode."
    static let lockFailed = "De chat kon niet worden vergrendeld. Probeer het opnieuw."
    static let unlockFailed = "De chat kon niet worden ontgrendeld. Probeer het opnieuw."
    static let lockedChats = "Vergrendelde chats"
    static let lockedEmpty = "Je hebt geen vergrendelde chats. Kies Chat vergrendelen in het menu van een chat."
    static let lockedRelock = "Nu vergrendelen"
    static let pinCreateTitle = "Kies een pincode"
    static let pinCreateBody = "Kies 4 cijfers. Daarmee open je je vergrendelde chats."
    static let pinConfirmTitle = "Herhaal je pincode"
    static let pinConfirmBody = "Typ dezelfde 4 cijfers nog een keer."
    static let pinEnterTitle = "Pincode"
    static let pinEnterBody = "Typ je pincode."
    static let pinMismatch = "De pincodes zijn niet hetzelfde. Probeer het opnieuw."
    static let pinWrong = "Deze pincode klopt niet."
    static let pinBlocked = "Te vaak fout. Probeer het over 5 minuten opnieuw."
    static let pinCodeFailed = "Er ging iets mis. Probeer het opnieuw."
    static let pinForgot = "Pincode vergeten?"
    static let pinResetQuestion = "Pincode resetten?"
    static let pinResetBody = "Al je vergrendelde chats worden verwijderd. Dit kan niet terug."
    static let pinResetConfirm = "Resetten en verwijderen"

    // The page of a project (web /project/<id>), with the texts of the web.
    static let projectTabChats = "Chats"
    static let projectSources = "Bronnen"
    static let projectEmpty = "Nog geen chats. Chats in dit project verschijnen hier."
    static let sourcesEmptyTitle = "Geef Ayla meer context"
    static let sourcesEmpty = "Voeg bronnen toe om Ayla meer context over je project te geven. Ayla gebruikt ze in alle chats van dit project."
    static let sourcesAdd = "Bronnen toevoegen"
    static let sourcesUpload = "Bestand uploaden"
    static let sourcesFromVault = "Uit kluis halen"
    static let sourcesRemove = "Verwijderen uit project"
    static let sourcesFailed = "Dit is niet gelukt. Probeer het opnieuw."
    static let sourcesLoading = "Bronnen laden…"
    static let sourcesNoMatch = "Geen bronnen met dit filter."
    static let sourcesSortLabel = "Sorteren"
    static let sourcesFilterLabel = "Filteren"
    static let sourcesSortNewest = "Nieuwste"
    static let sourcesSortOldest = "Oudste"
    static let sourcesSortName = "Naam"
    static let sourcesAllKinds = "Alles"
    static let sourcesPickTitle = "Uit kluis halen"
    static let sourcesPickEmpty = "Je kluis is nog leeg. Voeg eerst iets toe aan je kluis."
    static let sourcesPickNoMatch = "Niets gevonden in je kluis."

    // Accountpincode (web Privacy): the same PIN on every device, so it can be changed or reset from here too.
    static let accountPinTitle = "Accountpincode"
    static let accountPinIntro = "Gebruik je accountpincode om je vergrendelde chats op al je apparaten te beveiligen."
    static let accountPinNone = "Je hebt nog geen accountpincode. Die kies je zodra je een chat vergrendelt."
    static let accountPinChangeTitle = "Pincode wijzigen"
    static let accountPinChangeBody = "Kies een nieuwe pincode voor je vergrendelde chats."
    static let accountPinChangeButton = "Wijzigen"
    static let accountPinResetTitle = "Pincode resetten"
    static let accountPinResetBody = "Reset je pincode alleen als je je huidige pincode bent vergeten. Je vergrendelde chats blijven bewaard."
    static let accountPinResetButton = "Resetten"
    static let accountPinCurrentTitle = "Huidige pincode"
    static let accountPinCurrentBody = "Typ je huidige pincode om een nieuwe te kiezen."
    static let accountPinNewTitle = "Kies een nieuwe pincode"
    static let accountPinNewBody = "Kies 4 nieuwe cijfers. Daarmee open je vanaf nu je vergrendelde chats."
    static let accountPinChanged = "Je pincode is gewijzigd."
    static let accountPinWasReset = "Je pincode is gereset. Je vergrendelde chats zijn bewaard."
    static let accountPinDeleted = "Je pincode en je vergrendelde chats zijn verwijderd."
    static let accountPinVerifyTitle = "Bevestig dat jij het bent"
    static let accountPinVerifyBody = "Typ de code uit je authenticator-app. Daarna kies je een nieuwe pincode. Je vergrendelde chats blijven bewaard."
    static let accountPinDeleteAll = "Of verwijder alles en begin opnieuw"
    static let accountPinDeleteBody = "Je pincode wordt gewist en al je vergrendelde chats worden definitief verwijderd. Dit kan niet ongedaan worden gemaakt."
    static let pinCheckFailed = "Er ging iets mis. Probeer het opnieuw."
    static func deleteChatMessage(_ title: String) -> String { "De chat “\(title)” wordt voor altijd verwijderd. Dit kan niet terug." }
    static let accountPinDeleteAllHint = "Kun je niet bij je authenticator-app? Dan kun je je vergrendelde chats verwijderen en een nieuwe pincode kiezen."
    static let accountPinNotReady = "Dit komt beschikbaar zodra PAVE is bijgewerkt."
    static let accountPinVerifyAgain = "Bevestig opnieuw met je authenticator-app en probeer het nog een keer."
    static let tooManyFiles = "Je kunt \(AylaAttachment.maxCount) bestanden tegelijk toevoegen."
}
