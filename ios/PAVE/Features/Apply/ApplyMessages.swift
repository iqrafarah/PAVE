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

    // Choosing a design
    static let chooseDesign = "Kies een ontwerp"
    static func chooseDesignHint(_ vacancy: Vacancy) -> String {
        "Voor \(vacancy.title) bij \(vacancy.company). Al ingevuld met jouw gegevens; wisselen kan later altijd."
    }
    static let allDesigns = "Alle"
    static let withPhoto = "Met foto"
    static func useDesign(_ design: ApplicationTemplate) -> String { "Gebruik \(template(design))" }
    static let howToBegin = "Hoe wil je beginnen?"
    static func chosenDesign(_ design: ApplicationTemplate) -> String { "Ontwerp \(template(design)). Je cv en brief horen bij elkaar." }
    static let aylaFills = "Ayla vult het in"
    static func aylaFillsHint(_ count: Int) -> String {
        count == 0
            ? "Ayla schrijft je profiel en brief. Ze mag nog geen bewijs uit je kluis bekijken, dus ze schrijft algemeen. Jij past daarna alles aan."
            : "Ayla schrijft je profiel en brief met het bewijs uit je kluis dat ze mag bekijken (\(count)). Jij past daarna alles aan."
    }
    static let fillYourself = "Zelf invullen"
    static let fillYourselfHint = "Je gegevens uit de kluis staan erin. Je profiel en brief schrijf je zelf, met hints waar wat komt."
    static let otherDesign = "Ander ontwerp kiezen"

    static func template(_ template: ApplicationTemplate) -> String {
        switch template {
        case .sage: "Salie"
        case .night: "Nacht"
        case .frame: "Kader"
        case .coral: "Koraal"
        case .column: "Zuil"
        case .line: "Lijn"
        case .plain: "Helder"
        case .block: "Tegel"
        case .halo: "Kring"
        case .tilt: "Schuin"
        }
    }

    static func style(_ style: ApplicationTemplate.Style) -> String {
        switch style {
        case .business: "Zakelijk"
        case .creative: "Creatief"
        case .minimal: "Minimalistisch"
        case .elegant: "Elegant"
        }
    }

    static func palette(_ palette: ApplicationPalette) -> String {
        switch palette {
        case .pave: "PAVE"
        case .sage: "Salie"
        case .ocean: "Oceaan"
        case .teal: "Petrol"
        case .rose: "Roos"
        case .night: "Nacht"
        case .coral: "Koraal"
        case .lavender: "Lavendel"
        case .mono: "Zwart-wit"
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
    static let profileHint = "Schrijf hier in 2 of 3 zinnen wie je bent en wat je zoekt."
    static func paragraphHint(_ index: Int) -> String {
        switch index {
        case 0: "Waarom deze vacature en dit bedrijf?"
        case 1: "Wat breng je mee? Noem een voorbeeld uit je kluis."
        default: "Sluit af en nodig uit tot een gesprek."
        }
    }
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
