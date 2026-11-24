import Foundation
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
    static func page(_ number: Int, of count: Int) -> String { "Pagina \(number) van \(count)" }
    static func pagesNote(_ count: Int, _ document: ApplicationDocumentKind) -> String {
        document == .cv
            ? "Je cv is \(count) pagina's. Eén pagina leest het prettigst."
            : "Je brief is \(count) pagina's. Een brief past het best op één pagina."
    }
    static let chooseDesign = "Kies een ontwerp"
    static func chooseDesignHint(_ vacancy: Vacancy) -> String {
        "Voor \(vacancy.title) bij \(vacancy.company). Al ingevuld met jouw gegevens; wisselen kan later altijd."
    }
    static let allDesigns = "Alle"
    static let withPhoto = "Met foto"
    static func useDesign(_ design: ApplicationTemplate) -> String { "Gebruik \(template(design))" }
    static let aylaFills = "Ayla vult het in"
    static let fillYourself = "Zelf invullen"
    static let otherDesign = "Ander ontwerp kiezen"

    // My application
    static let hubTitle = "Mijn sollicitatie"
    static func status(_ status: ApplicationStatus) -> String {
        switch status {
        case .concept: "Concept"
        case .sent: "Verstuurd"
        case .interview: "Gesprek"
        case .offer: "Aanbod"
        case .rejected: "Afgewezen"
        }
    }
    static let statusLabel = "Status"
    static let statusHint = "Dit houd je zelf bij. PAVE stuurt niets naar het bedrijf."
    static let deadline = "Deadline"
    static let setDeadline = "Deadline instellen"
    static let note = "Notitie"
    static let notePrompt = "Bijvoorbeeld: contactpersoon of wat je nog wilt doen"
    static let yourDocuments = "Je cv en brief"
    static func lastChanged(_ date: Date) -> String {
        "Laatst gewijzigd op \(date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "nl_NL"))))"
    }
    static let nextSteps = "Volgende stappen"
    static func stillMissing(_ count: Int) -> String { count == 1 ? "1 eis staat nog niet op je cv" : "\(count) eisen staan nog niet op je cv" }
    static let whatCanIDo = "Wat kan ik doen?"
    static let allCovered = "Alles wat de vacature vraagt staat op je cv."
    static let practice = "Oefen het gesprek"
    static let editCV = "Cv bewerken"
    static let editLetter = "Brief bewerken"

    // What goes in
    static let whatGoesIn = "Wat komt erin?"
    static func whatGoesInHint(_ vacancy: Vacancy) -> String {
        "Ayla's voorstel voor \(vacancy.title) bij \(vacancy.company). Zet aan of uit wat je wilt laten zien."
    }
    static let whatGoesInEditorHint = "Zet aan of uit wat op je cv staat."
    static let fitsOnOnePage = "Past op 1 pagina"
    static func pageCount(_ count: Int) -> String { "\(count) pagina's" }
    static let makeItFit = "Maak passend op 1 pagina"
    static let alreadyFits = "Je cv past al op 1 pagina."
    static let backToProposal = "Terug naar Ayla's voorstel"
    static let aylaMayNotSee = "Ayla mag dit niet bekijken en schrijft er niet over"
    static let nothingInVault = "Er staat nog niets in je kluis voor dit onderdeel."
    static func reason(_ reason: ApplicationProposal.Reason) -> String {
        switch reason {
        case .fits(let skills): "Past bij \(skills.joined(separator: " en "))"
        case .current: "Loopt nog"
        case .recent: "Recent"
        case .education: "Hoort op elk cv"
        case .oldAndUnrelated: "Lang geleden en past minder bij deze vacature"
        case .forOnePage: "Uit, zodat je cv op 1 pagina past"
        }
    }
    static let verified = "geverifieerd"
    static let verifiedNote = "In PAVE geverifieerd door de organisatie zelf."
    static let showVerified = "Vinkje bij geverifieerd bewijs"
    static let showVerifiedHint = "Op je cv staat een vinkje bij bewijs dat door de organisatie is geverifieerd. Pas je de titel, organisatie of periode aan, dan vervalt het vinkje."
    static let nothingVerified = "Er staat nog geen geverifieerd bewijs op je cv."

    // What the vacancy asks for
    static let asked = "Wat de vacature vraagt"
    static func askedSummary(covered: Int, of count: Int, available: Int) -> String {
        let base = "\(covered) van de \(count) staan op je cv"
        return available == 0 ? base : "\(base), \(available) kun je aanzetten"
    }
    static func coverage(_ state: ApplicationCoverage.State) -> String {
        switch state {
        case .shown(let titles):
            titles.count > 1 ? "Staat op je cv bij \(titles[0]) en \(titles.count - 1) andere" : "Staat op je cv bij \(titles.first ?? "")"
        case .named: "Staat bij je vaardigheden, zonder bewijs erachter"
        case .available: "Staat in je kluis, maar niet op je cv"
        case .missing: "Staat nog niet in je kluis"
        }
    }
    static let turnOn = "Zet aan"
    static let focus = "Waar wil je de nadruk op leggen?"
    static let focusHint = "Hoeft niet. Ayla legt hier de nadruk op in je profiel en brief, voor zover je bewijs dat laat zien."
    static let focusPrompt = "Bijvoorbeeld: samenwerken met klanten"

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
    // Ayla asks on
    static func aylaAsks(_ count: Int) -> String { count == 1 ? "Ayla heeft 1 vraag" : "Ayla heeft \(count) vragen" }
    static let questionsTitle = "Vragen van Ayla"
    static let questionsHint = "Je antwoord komt in dat onderdeel van je cv. Ayla gebruikt alleen wat je hier schrijft en wat ze al mocht bekijken."
    static func questionAbout(_ title: String) -> String { "Bij \(title)" }
    static let answerPrompt = "Je antwoord, in één zin"
    static let workIn = "Verwerk in je cv"
    static let skip = "Sla over"
    static let workedIn = "Verwerkt in je cv"
    static let keepInVault = "Bewaar ook in je kluis"
    static let keptInVault = "Bewaard in je kluis"
    static let keepHint = "Je antwoord komt bij de beschrijving van dit bewijsstuk."
    static let keepVerifiedHint = "Dit bewijsstuk is geverifieerd. Als je het aanvult, moet het opnieuw geverifieerd worden en vervalt het vinkje op je cv."
    static let keepFailed = "Het bewaren in je kluis lukte niet. Probeer het zo opnieuw."
    static let noQuestions = "Ayla heeft nu geen vragen."
    static let askOn = "Laat Ayla doorvragen"
    static let asking = "Ayla leest je cv…"
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
