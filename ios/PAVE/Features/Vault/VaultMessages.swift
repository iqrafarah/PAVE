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
    static let folderNameTaken = "Je hebt al een map met deze naam."

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
        case .unavailable, .missingColumn: "Er ging iets mis. Probeer het zo nog een keer."
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
