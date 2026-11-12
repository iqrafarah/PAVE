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
    static let hideCategoryMessage = "De items blijven gewoon in je kluis staan. Je zet de map terug met de plusknop."
    static let folderNameTaken = "Je hebt al een map met deze naam. Kies een andere naam."

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
        case .fileRejected: "Dit bestand kan niet in je kluis. Kies een PDF, Word-bestand, tekst of foto tot 20 MB."
        case .unavailable, .missingColumn: "Er ging iets mis. Probeer het zo nog een keer."
        }
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
    static let coverHint = "Kies een foto voor de omslag"
    static let coverMissing = "Kies een foto voor de omslag, of kies Geen omslag."
    static let coverNotYet = "Je bewijs staat in je kluis. De omslag kan nog niet bewaard worden; dat komt binnenkort."
    static let skillsFromVault = "Vaardigheden uit je kluis"
    static let skillsOwn = "Zelf een vaardigheid toevoegen"
    static let skillsPrompt = "Zoek of typ een vaardigheid"
    static let skillsEmpty = "Je kluis heeft nog geen vaardigheden. Voeg er hieronder zelf een toe."
    static let added = "Bewijs toegevoegd"
    static let addedMessage = "Het staat als Niet bevestigd in je kluis, tot een school of werkgever het bevestigt."
    static let saving = "Toevoegen…"
    static let discardTitle = "Stoppen met toevoegen?"
    static let discardMessage = "Wat je hebt ingevuld, wordt niet bewaard."

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

    static func missing(_ field: VaultItemDraft.Field, category: VaultCategory) -> String {
        switch field {
        case .title: "Geef je bewijs een titel."
        case .organisation: "Vul de organisatie of school in."
        case .period: category.hasPeriod ? "Kies wanneer je begon." : "Kies wanneer je dit behaalde."
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
