import PAVECore

/// The texts of the vault in one place, so web can use the same words.
enum VaultMessages {
    static let emptyTitle = "Je kluis is nog leeg"
    static let emptyMessage = "Bewaar hier je diploma's, certificaten, projecten en ervaringen. Dan heb je alles op één plek."
    static let noResultsTitle = "Niets gevonden"
    static let noResultsMessage = "Probeer een ander woord of zet de filters uit."
    static let emptyFolderMessage = "Houd een item ingedrukt en kies Verplaatsen naar map."
    static let notInDemoTitle = "Geen kluis in de demo"
    static let notInDemoMessage = "Log in met je eigen account om je kluis te gebruiken."
    static let loadFailedTitle = "Je kluis kon niet laden"
    static let newFolderTitle = "Nieuwe map"
    static let folderNameMissing = "Geef je map een naam."
    static let deleteFolderMessage = "De items in deze map blijven gewoon in je kluis staan."
    static let deleteItemMessage = "Dit haalt het item en de bestanden erbij voorgoed uit je kluis, ook op het web. Dit kun je niet ongedaan maken."
    static let folderNameTaken = "Je hebt al een map met deze naam. Kies een andere naam."

    static func newKindFolder(_ name: String) -> String {
        "\(name) (nieuwe map)"
    }

    static func inFolders(_ names: [String]) -> String {
        names.count == 1 ? "In de map \(names[0])" : "In de mappen \(names.joined(separator: ", "))"
    }

    static func itemCount(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }

    static func emptyCategoryTitle(_ category: VaultCategory) -> String {
        "Nog geen \(category.title.lowercased())"
    }

    static func message(for error: VaultError) -> String {
        switch error {
        case .noConnection: "Je kluis is niet bereikbaar. Controleer je internetverbinding en probeer het opnieuw."
        case .notSignedIn: "Je sessie is verlopen. Log opnieuw in om je kluis te openen."
        case .notAllowed: "Dit mag niet met je account. Log opnieuw in en probeer het nog een keer."
        case .duplicateFolderName: folderNameTaken
        case .notSetUp: "Dit is nog niet beschikbaar. Probeer het later nog een keer."
        case .fileRejected: "Dit bestand kan niet in je kluis. Kies een PDF, Word-bestand, tekst of foto tot 20 MB."
        case .unavailable, .missingColumn: "Er ging iets mis. Probeer het zo nog een keer."
        }
    }

    /// In a debug build the technical reason goes under the message, so a test can say exactly what failed.
    static func withDetail(_ message: String) -> String {
        #if DEBUG
        if let detail = SupabaseVaultService.lastFailure { return "\(message)\n[\(detail)]" }
        #endif
        return message
    }

    // MARK: Bewijs toevoegen

    static let addTitle = "Bewijs toevoegen"
    static let steps = ["Basis", "Documenten", "Vaardigheden", "Toestemming"]
    static let uploadTitle = "Tik om te uploaden"
    static let uploadHint = "PDF, Word, tekst of foto, tot 20 MB"
    static let withoutFileTitle = "Voeg een ervaring toe zonder bestand"
    static let withoutFileMessage = "Geen document, geen probleem. Je kunt ook zelf ervaringen toevoegen."
    static let coverTitle = "Omslag"
    static let noCover = "Geen omslag"
    static let withCover = "Omslag"
    static let coverHint = "Je eigen foto in de band boven je kaart"
    static let logoTitle = "Logo"
    static let logoHint = "Komt in de cirkel op je kaart, bijvoorbeeld het logo van je school of werkgever."
    static let logoChoose = "Logo kiezen"
    static let logoReplace = "Ander logo kiezen"
    static let logoRemove = "Logo weghalen"
    static let logoHintChosen = "Tik op het logo om het te verplaatsen, te vervangen of weg te halen."
    static let reframe = "Verplaatsen en schalen"
    static let coverChosen = "Staat in de band boven je kaart"
    static let coverRemove = "Omslag weghalen"
    static let coverActions = "Omslag aanpassen"
    static let noCoverWithLogo = "De band krijgt de sterkste kleur uit je logo."
    static let noCoverWithoutLogo = "Kies je een logo, dan krijgt de band de sterkste kleur daaruit."
    static let documentsTitle = "Documenten"
    static let documentsEmpty = "Nog geen document. Zonder bestand kan ook: dan staat je ervaring er zelf beschreven in."
    static let addDocument = "Document toevoegen"
    static let addAnotherDocument = "Nog een document toevoegen"
    static let coverMissing = "Kies een foto voor de omslag, of kies Geen omslag."
    static let coverNotYet = "Je bewijs staat in je kluis. Het logo en de omslag kunnen nog niet bewaard worden; dat komt binnenkort."
    static let skillsFromVault = "Vaardigheden uit je kluis"
    static let skillsOwn = "Zelf een vaardigheid toevoegen"
    static let skillsPrompt = "Zoek of typ een vaardigheid"
    static let skillsEmpty = "Je kluis heeft nog geen vaardigheden. Voeg er hieronder zelf een toe."
    static let aylaSkillsIntro = "Ayla kan vaardigheden voorstellen die bij dit bewijs passen. Ze ziet alleen wat je in dit formulier invulde."
    static let aylaSkillsOnlyForm = "Ayla ziet alleen wat je in dit formulier invulde."
    static let aylaSkillsAsk = "Vraag Ayla om voorstellen"
    static let aylaSkillsAgain = "Opnieuw vragen"
    static let aylaSkillsThinking = "Ayla bekijkt je bewijs…"
    static let aylaSkillsNone = "Ayla vond geen nieuwe vaardigheden in dit bewijs. Vul de omschrijving aan en vraag het opnieuw."

    static func aylaSkills(_ error: VaultError) -> String {
        switch error {
        case .notSetUp: "Voorstellen van Ayla zijn nog niet beschikbaar. Je kunt zelf vaardigheden kiezen."
        case .noConnection: "Geen verbinding. Probeer het zo nog een keer."
        default: "Ayla kon nu geen voorstellen doen. Probeer het zo nog een keer."
        }
    }

    static let added = "Bewijs toegevoegd"
    static let addedMessage = "Het staat als Niet bevestigd in je kluis, tot een school of werkgever het bevestigt."
    static let saving = "Toevoegen…"
    static let discardChangesTitle = "Wijzigingen weggooien?"
    static let reconfirmTitle = "Dit bewijs is bevestigd"
    static let reconfirmMessage = "Pas je de gegevens of bestanden aan, dan staat het weer als Niet bevestigd in je kluis tot het opnieuw bevestigd is."
    static let reconfirmQuestion = "Opnieuw laten bevestigen?"
    static let discardTitle = "Stoppen met toevoegen?"
    static let discardMessage = "Wat je hebt ingevuld, wordt niet bewaard."

    static let aylaConsentMeaning = "Dan neemt Ayla dit mee in je vragen en zoekopdrachten. Je kunt het altijd weer uitzetten."

    static func aylaConsent(hasFile: Bool) -> String {
        hasFile ? "Ayla mag dit document bekijken en gebruiken" : "Ayla mag dit bewijs bekijken en gebruiken"
    }

    static func skillAdd(_ name: String) -> String {
        "\u{201C}\(name)\u{201D} toevoegen"
    }

    static func upload(_ problem: VaultUpload.Problem) -> String {
        switch problem {
        case .empty: "Dit bestand is leeg. Kies een ander bestand."
        case .tooLarge: "Dit bestand is groter dan 20 MB. Kies een kleiner bestand."
        case .unsupportedType: "Dit soort bestand kan niet in je kluis. Kies een PDF, Word-bestand, tekst of foto."
        case .notAnImage: "Kies een foto of afbeelding voor de omslag."
        }
    }

    static func missing(_ field: VaultItemDraft.Field, isPeriod: Bool) -> String {
        switch field {
        case .title: "Geef je bewijs een titel."
        case .organisation: "Vul de organisatie of school in."
        case .period: isPeriod ? "Kies wanneer je begon." : "Kies de datum."
        case .description: "Beschrijf kort wat je hebt gedaan of geleerd."
        }
    }

    static func problem(_ problem: VaultItemDraft.Problem) -> String {
        switch problem {
        case .missingTitle: "Geef het item een titel."
        case .titleTooLong: "De titel mag maximaal \(VaultItemDraft.maximumTitleLength) tekens zijn."
        case .endBeforeStart: "De einddatum ligt voor de begindatum."
        case .descriptionTooLong: "De omschrijving is te lang."
        }
    }
}

extension VaultItem.Status {
    var title: String {
        switch self {
        case .verified: "Geverifieerd"
        case .toVerify: "Niet bevestigd"
        case .rejected: "Afgewezen"
        }
    }

    var explanation: String {
        switch self {
        case .verified: "Bevestigd door een officiële of vertrouwde bron. Daarom kun je dit item niet meer aanpassen."
        case .toVerify: "Nog niet bevestigd door een school, opleiding of werkgever."
        case .rejected: "De organisatie kon dit niet bevestigen. Kijk of alles klopt en pas het zo nodig aan."
        }
    }
}

extension VaultItem.Source {
    var title: String {
        switch self {
        case .user: "Zelf toegevoegd"
        case .organization: "Van een organisatie"
        case .ayla: "Voorgesteld door Ayla"
        case .import: "Geïmporteerd"
        }
    }
}

extension VaultFilter.Origin {
    var title: String {
        switch self {
        case .own: "Zelf toegevoegd"
        case .organisation: "Van een organisatie"
        case .ayla: "Via Ayla"
        }
    }
}

extension VaultFilter.Order {
    var title: String {
        switch self {
        case .newest: "Nieuwste eerst"
        case .oldest: "Oudste eerst"
        }
    }
}
