import PAVECore

/// The words of making a CV and a letter for a vacancy. Kept in docs/ui-teksten.md under "Cv en motivatiebrief".
enum ApplyMessages {
    static func title(_ vacancy: Vacancy) -> String { "Solliciteren bij \(vacancy.company)" }
    static let cv = "Cv"
    static let letter = "Motivatiebrief"
    static let close = "Sluiten"
    static let export = "Exporteren"
    static let exportCV = "Cv als pdf"
    static let exportLetter = "Brief als pdf"
    static let exportFailed = "De pdf kon niet worden gemaakt. Probeer het opnieuw."
    static let templates = "Sjabloon"
    static let design = "Ontwerp"
    static let content = "Inhoud"
    static let color = "Kleur"
    static let photo = "Profielfoto tonen"
    static let photoMissing = "Voeg een profielfoto toe bij Instellingen › Account om hem hier te tonen."
    static let sections = "Onderdelen"
    static let tapToEdit = "Tik op een onderdeel om het aan te passen."

    static func template(_ template: ApplicationTemplate) -> String {
        switch template {
        case .calm: "Rustig"
        case .modern: "Modern"
        case .bold: "Opvallend"
        case .compact: "Compact"
        }
    }

    static func section(_ kind: CVSection.Kind) -> String {
        switch kind {
        case .experience: "Werkervaring"
        case .education: "Opleiding"
        case .certificates: "Certificaten"
        case .projects: "Projecten"
        }
    }

    static let profileHeading = "Profiel"
    static let skillsHeading = "Vaardigheden"
    static let contactHeading = "Contact"

    // Editing
    static let personal = "Gegevens"
    static let name = "Naam"
    static let headline = "Regel onder je naam"
    static let headlineHint = "Bijvoorbeeld: Student HBO-ICT"
    static let email = "E-mail"
    static let phone = "Telefoon"
    static let city = "Woonplaats"
    static let entryTitle = "Titel"
    static let entryOrganisation = "Organisatie"
    static let entryPeriod = "Periode"
    static let entryDescription = "Beschrijving"
    static let showOnCV = "Tonen op je cv"
    static let skillsHint = "Eén vaardigheid per regel. Die uit de vacature staan bovenaan."
    static let salutation = "Aanhef"
    static let closingLine = "Afsluiting"
    static let signature = "Ondertekening"
    static let paragraph = "Alinea"
    static let addParagraph = "Alinea toevoegen"
    static let removeParagraph = "Alinea verwijderen"
    static let removeParagraphQuestion = "Deze alinea verwijderen?"
    static let cancel = "Annuleer"
    static let done = "Klaar"
    static let fromVault = "Uit je kluis"
    static let typedByHand = "Zelf toegevoegd"

    // Ayla
    static let aylaWrites = "Ayla schrijft mee"
    static let aylaWritesShort = "Ayla schrijft"
    static let aylaProfile = "Laat Ayla je profiel schrijven"
    static let aylaLetter = "Laat Ayla de brief schrijven"
    static let aylaWriting = "Ayla schrijft…"
    static let aylaFailed = "Ayla kon nu niet schrijven. Probeer het zo opnieuw."
    static func aylaUses(_ count: Int) -> String {
        count == 0
            ? "Ayla mag nog geen bewijs uit je kluis bekijken, dus ze schrijft algemeen. Zet bij een bewijsstuk \"Ayla mag dit bekijken en gebruiken\" aan."
            : count == 1 ? "Ayla gebruikt alleen het bewijsstuk dat ze mag bekijken." : "Ayla gebruikt alleen de \(count) bewijsstukken die ze mag bekijken."
    }
    static func rewrite(_ rewrite: ApplicationWritingRequest.Rewrite) -> String {
        switch rewrite {
        case .shorter: "Korter"
        case .stronger: "Sterker voor deze vacature"
        case .english: "In het Engels"
        case .formal: "Formeler"
        case .personal: "Persoonlijker"
        }
    }
    static let undo = "Ongedaan maken"
}
