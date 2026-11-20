import PAVECore

/// The texts of the vault in one place, so web can use the same words.
enum VaultMessages {
    static let scanFailed = "Je scan kon niet gelezen worden. Probeer het nog eens of voeg een bestand toe."
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
    static let ownFolderColor = "Eigen kleur"
    static let ownFolderColorHint = "Kies een kleur van je eigen."
    static let changeOwnFolderColor = "Andere eigen kleur kiezen"
    static let pinFolder = "Vastzetten"
    static let unpinFolder = "Losmaken"
    static func folderPinned(_ name: String) -> String { "\(name) staat nu vooraan." }
    static func folderUnpinned(_ name: String) -> String { "\(name) is losgemaakt." }
    static func allFolders(_ count: Int) -> String { "Alle mappen (\(count))" }
    static let allFoldersTitle = "Alle mappen"
    static func folderCount(_ count: Int) -> String { count == 1 ? "1 map" : "\(count) mappen" }
    static let searchFolders = "Zoeken in je mappen"
    static func noFoldersFound(_ query: String) -> String { "Geen mappen gevonden voor \"\(query)\"." }
    static func downloadFile(_ name: String) -> String { "\(name) downloaden" }
    static let downloadAll = "Alles downloaden"
    static let download = "Downloaden"
    static let downloadFailed = "Downloaden lukte niet. Probeer het opnieuw."
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
        case .validationOrganisationNotFound: "Deze organisatie is niet bekend bij PAVE. Controleer de naam of neem contact op met je organisatie."
        case .validationNoReviewer: "Er is nog geen beoordelaar ingesteld voor deze organisatie. Neem contact op met je organisatie."
        case .validationAlreadyPending: "Voor dit bewijs staat al een verificatieaanvraag open."
        case .validationItemUnavailable: "Dit bewijs kan niet meer worden aangevraagd. Vernieuw de kluis en probeer opnieuw."
        case .validationInvalidChoice: "Deze organisatie-, vestigings- of contactkeuze is niet meer geldig. Kies de gegevens opnieuw."
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
    static func imagesNotYet(cover: Bool, logo: Bool) -> String {
        let what = cover && logo ? "Het logo en de omslag kunnen" : logo ? "Het logo kan" : "De omslag kan"
        return "Je bewijs staat in je kluis. \(what) nog niet bewaard worden; dat komt binnenkort."
    }
    static let skillsFromVault = "Vaardigheden uit je kluis"
    static let skillsOwn = "Zelf een vaardigheid toevoegen"
    static let skillsPrompt = "Zoek of typ een vaardigheid"
    static let skillsEmpty = "Je kluis heeft nog geen vaardigheden. Voeg er hieronder zelf een toe."
    static let aylaSkillsIntro = "Ayla kan vaardigheden voorstellen die bij dit bewijs passen. Ze kijkt naar wat je invulde en naar je bestanden, alleen voor dit voorstel."

    /// Under her proposals: what Ayla looked at, so it is clear where they come from.
    static func aylaSkillsLookedAt(files: Int) -> String {
        switch files {
        case 0: "Ayla keek alleen naar wat je invulde."
        case 1: "Ayla keek naar wat je invulde en naar 1 bestand, alleen voor dit voorstel."
        default: "Ayla keek naar wat je invulde en naar \(files) bestanden, alleen voor dit voorstel."
        }
    }
    static let aylaSkillsAsk = "Vraag Ayla om voorstellen"
    static let aylaSkillsAgain = "Opnieuw vragen"
    static let aylaSkillsThinking = "Ayla bekijkt je bewijs…"
    static let aylaSkillsNone = "Ayla vond geen nieuwe vaardigheden in dit bewijs. Vul de omschrijving aan of voeg een bestand toe en vraag het opnieuw."

    static func aylaSkills(_ error: VaultError) -> String {
        switch error {
        case .notSetUp: "Voorstellen van Ayla zijn nog niet beschikbaar. Je kunt zelf vaardigheden kiezen."
        case .noConnection: "Geen verbinding. Probeer het zo nog een keer."
        default: "Ayla kon nu geen voorstellen doen. Probeer het zo nog een keer."
        }
    }

    // "Laat Ayla invullen"
    static let aylaFillTitle = "Laat Ayla invullen"
    static let aylaFillButtonReading = "Ayla leest…"
    static let aylaFillReading = "Ayla leest je bestanden en vult alvast in…"
    static let aylaFillStop = "Zelf invullen"
    static let aylaFillAgain = "Opnieuw proberen"
    static let aylaFillEmpty = "Ayla kon niets uit je bestand halen. Vul het zelf in."
    static let aylaFilledTitle = "Ayla heeft dit ingevuld"
    static let aylaFilledMessage = "Controleer alles voordat je verdergaat. Wat Ayla niet in je bestand zag, is leeg gebleven."
    static let aylaFilledAnnouncement = "Ayla heeft het bewijs ingevuld. Controleer de velden."
    static let aylaSplitOne = "Eén bewijs"
    static let aylaSplitApart = "Apart toevoegen"
    static let nextEvidence = "Volgende bewijs"
    static let nextEvidenceSkip = "Klaar"

    static let dragToFolder = "Laat los op een map om het daarheen te verplaatsen."

    static func movedInto(_ title: String, folder: String) -> String {
        "\(title) staat nu in \(folder)."
    }
    static let draftBack = "Je concept is terug, zoals je het net achterliet."
    static let draftStartOver = "Opnieuw beginnen"
    static let aylaCoverNote = "Foto uit je document, gekozen door Ayla"

    static func aylaFill(_ error: VaultError) -> String {
        switch error {
        case .notSetUp: "Invullen door Ayla is nog niet beschikbaar. Vul het zelf in."
        case .noConnection: "Geen verbinding. Probeer het zo nog een keer, of vul het zelf in."
        default: "Ayla kon je bestand nu niet lezen. Probeer het zo nog een keer, of vul het zelf in."
        }
    }

    /// "Door Ayla · pagina 1": short, so it fits under a field in two columns.
    static func filledByAyla(source: String?) -> String {
        source.map { "Door Ayla · \($0)" } ?? "Ingevuld door Ayla"
    }

    static func aylaSplitTitle(_ titles: [String]) -> String {
        let list = titles.count > 1 ? titles.dropLast().joined(separator: ", ") + " en " + titles[titles.count - 1] : titles.first ?? ""
        return "Ayla ziet \(titles.count) bewijzen: \(list)."
    }

    static func aylaSplitHint(apart: Bool, first: String) -> String {
        apart ? "Je voegt ze na elkaar toe, elk al ingevuld. Eerst \(first)." : "Al je bestanden komen bij dit ene bewijs."
    }

    static func aylaLogoNote(source: String?) -> String {
        source.map { "Logo van \($0), gevonden door Ayla" } ?? "Logo uit je document, gekozen door Ayla"
    }

    static func nextEvidenceNote(_ title: String) -> String {
        "Ga verder met \(title), al ingevuld door Ayla. Of kies Klaar om te stoppen."
    }

    static let added = "Bewijs toegevoegd"
    static let addedMessage = "Het staat als Niet bevestigd in je kluis, tot een school of werkgever het bevestigt."
    static let saving = "Toevoegen…"
    static let discardChangesTitle = "Wijzigingen weggooien?"
    static let reconfirmTitle = "Dit bewijs is bevestigd"
    static let reconfirmMessage = "Pas je de gegevens of bestanden aan, dan staat het weer als Niet bevestigd in je kluis. Daarna kun je opnieuw bevestiging aanvragen."

    // MARK: Bevestiging aanvragen (only the front for now)

    static let requestAction = "Bevestiging aanvragen"
    static let requestAgainAction = "Opnieuw bevestiging aanvragen"
    static let awaitingReviewTitle = "In afwachting"

    static func awaitingReviewExplanation(_ organisation: String?) -> String {
        if let organisation, !organisation.isEmpty {
            return "Je aanvraag ligt bij \(organisation). Je krijgt een melding zodra je bewijs is beoordeeld."
        }
        return "Je aanvraag is verstuurd. Je krijgt een melding zodra je bewijs is beoordeeld."
    }

    static func rejectionReasonTitle(_ organisation: String?) -> String {
        if let organisation, !organisation.isEmpty { return "Reden van \(organisation)" }
        return "Reden van afwijzing"
    }
    static let requestPreviewLabel = "Voorbeeld"
    static let requestPreviewAccessibility = "Voorbeeld, werkt nog niet"
    static let requestNotActive = "Bevestiging aanvragen werkt nog niet. Je kunt alvast kijken hoe het wordt, maar er wordt niets verstuurd."
    static let requestWhoTitle = "Wie kan dit bevestigen?"
    static let requestOrganisationPrompt = "Bijv. Fontys of LiveWall"
    static let requestEmailTitle = "E-mailadres van je contactpersoon"
    static let requestMessageTitle = "Bericht"
    static let requestMessagePrompt = "Bijv. Wil je mijn eindstage bevestigen?"
    static let requestSharedTitle = "Dit ziet de ontvanger"
    static let requestSend = "Verzoek versturen"
    static let requestNotSentTitle = "Nog niet verstuurd"
    static let discardRequestTitle = "Verzoek weggooien?"
    static let sharedDescription = "Je omschrijving"

    static func requestNotSentMessage(_ organisation: String) -> String {
        let to = organisation.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Bevestiging aanvragen werkt nog niet in deze versie van PAVE. Er is niets naar \(to.isEmpty ? "de organisatie" : to) gestuurd en niets bewaard."
    }

    static func requestMissing(_ field: VaultConfirmationRequest.Field) -> String {
        switch field {
        case .organisation: "Kies een organisatie."
        case .location: "Kies een vestigingsplaats."
        case .department: "Kies een afdeling of opleiding."
        case .contact: "Kies de persoon die je bewijs kan bevestigen."
        }
    }

    static func sharedTitle(_ title: String, kind: String) -> String { "\(title) (\(kind.lowercased()))" }
    static func sharedFiles(_ count: Int) -> String { count == 1 ? "1 bestand" : "\(count) bestanden" }
    static func sharedSkills(_ count: Int) -> String { count == 1 ? "1 vaardigheid" : "\(count) vaardigheden" }
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

extension VaultConfirmationRequest.Recipient {
    var title: String {
        switch self {
        case .school: "School of opleiding"
        case .employer: "Werkgever of stagebedrijf"
        case .mentor: "Docent of begeleider"
        }
    }

    var example: String {
        switch self {
        case .school: "Voor diploma's, cijfers en certificaten."
        case .employer: "Voor werkervaring en stages."
        case .mentor: "Voor projecten, feedback en vaardigheden."
        }
    }

    var organisationLabel: String {
        switch self {
        case .school: "School of opleiding"
        case .employer: "Werkgever of stagebedrijf"
        case .mentor: "School of organisatie van je begeleider"
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
        case .verified: "Bevestigd door een officiële of vertrouwde bron. Pas je iets aan, dan moet het opnieuw bevestigd worden."
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
        case .custom: "Eigen volgorde"
        }
    }
}
