import Foundation
import PAVECore

/// The words of making a CV and a letter for a vacancy. Kept in docs/ui-teksten.md under "Cv en motivatiebrief".
enum ApplyMessages {
    static func title(_ vacancy: Vacancy) -> String { "Solliciteren bij \(vacancy.company)" }
    static let cv = "Cv"
    static let letter = "Motivatiebrief"
    static let letterShort = "Brief"
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

    static let history = "Geschiedenis"

    // Going back, stopping and sharing
    static let backToApplication = "Terug naar je sollicitatie"
    static let steps = ["Ontwerp", "Inhoud", "Schrijven"]
    static let saved = "Bewaard op dit toestel"

    // The demo invitation after applying
    static let demo = "Demo"
    static let fromEmployers = "Van werkgevers · demo"
    static let invitationTitle = "Uitnodiging kennismaking"
    static func invitationText(_ vacancy: Vacancy) -> String {
        "\(vacancy.company) wil je graag spreken over \(vacancy.title). Kies een moment dat je uitkomt."
    }
    static let invitationDemoNote = "Dit bericht is nagespeeld voor de demo; er is geen echte werkgever bij betrokken."
    static func slot(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute().locale(Locale(identifier: "nl_NL")))
    }
    static func talkPlanned(_ date: Date) -> String { "Je gesprek is op \(slot(date))" }
    static let talkToCalendar = "Zet in je agenda"
    static func talkCalendarTitle(_ vacancy: Vacancy) -> String { "Kennismaking \(vacancy.company)" }
    static let talkCalendarNotes = "Kennismakingsgesprek, gepland in PAVE (demo). Neem je cv mee."
    static let prepTitle = "Voorbereiden"
    static func prep(_ step: ApplicationInvitation.PrepStep, _ vacancy: Vacancy) -> String {
        switch step {
        case .rereadVacancy: "Lees de vacature nog eens door"
        case .readAboutCompany: "Lees wat er over \(vacancy.company) bekend is"
        case .practise: "Oefen het gesprek met Ayla"
        case .questions: "Bedenk twee vragen voor hen"
        case .route: "Plan je reis of test je videoverbinding"
        }
    }
    static func prepCount(_ done: Int, of total: Int) -> String { "\(done) van \(total) gedaan" }
    static func sharedLooks(_ count: Int) -> String {
        switch count {
        case 0: "Gedeeld, nog niet bekeken"
        case 1: "Gedeeld, 1 keer bekeken"
        default: "Gedeeld, \(count) keer bekeken"
        }
    }
    static func backToApplicationAt(_ company: String) -> String { "Terug naar je sollicitatie bij \(company)" }
    static let stopQuestion = "Stoppen met deze sollicitatie?"
    static let stopHint = "Je gekozen ontwerp en inhoud worden niet bewaard."
    static let stop = "Stoppen"
    static let goOn = "Doorgaan"
    static let share = "Delen"
    static func shareWith(_ company: String) -> String { "Deel met \(company)" }
    static func shareTitle(_ company: String) -> String { "Delen met \(company)" }
    static func shareHint(_ company: String) -> String {
        "Je kiest zelf wat \(company) ziet en hoe lang. Je kunt het altijd pauzeren of intrekken."
    }
    static let shareAgain = "Nog een keer delen"
    static let markSentQuestion = "Zet je sollicitatie op Verstuurd?"
    static func markSentHint(_ company: String) -> String {
        "Je hebt gedeeld met \(company). Dit houd je zelf bij; PAVE stuurt niets naar het bedrijf."
    }
    static let markSent = "Op Verstuurd zetten"
    static let notNow = "Niet nu"
    static func historyLine(_ change: ApplicationTracking.Change) -> String {
        "\(status(change.status)) · \(change.date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "nl_NL"))))"
    }
    static let remindMe = "Herinner me"
    static let remindHint = "Je krijgt een melding de dag voor je deadline en een week nadat je Verstuurd zet. De meldingen blijven op dit toestel."
    static let remindDenied = "Meldingen staan uit voor PAVE. Zet ze aan in de Instellingen van je iPhone om herinneringen te krijgen."
    static func deadlineDistance(_ distance: ApplicationDeadline) -> String {
        switch distance {
        case .overdue(let days): days == 1 ? "Verlopen, 1 dag geleden" : "Verlopen, \(days) dagen geleden"
        case .today: "Vandaag"
        case .upcoming(let days): days == 1 ? "Morgen" : "Over \(days) dagen"
        }
    }
    static func reminderTitle(_ kind: ApplicationReminder.Kind) -> String {
        switch kind {
        case .deadlineTomorrow: "Morgen is de deadline"
        case .deadlineToday: "Vandaag is de deadline"
        case .followUp: "Al iets gehoord?"
        case .invitation: "Uitnodiging voor een kennismaking"
        }
    }
    static func reminderBody(_ reminder: ApplicationReminder) -> String {
        let job = "\(reminder.vacancyTitle) bij \(reminder.company)"
        switch reminder.kind {
        case .followUp: return "Je solliciteerde een week geleden op \(job). Zet de status bij als er nieuws is."
        case .invitation: return "\(reminder.company) wil je spreken over \(reminder.vacancyTitle). Dit is een demo in PAVE."
        default: return "Je sollicitatie voor \(job) staat nog op concept."
        }
    }

    static func deadlineCard(_ distance: ApplicationDeadline) -> String {
        switch distance {
        case .today: "Je deadline is vandaag"
        case .upcoming(let days): days == 1 ? "Je deadline is morgen" : "Je deadline is over \(days) dagen"
        case .overdue: "Je deadline is verlopen"
        }
    }
    static let openApplicationHint = "Opent je sollicitatie"
    static let foundDeadline = "In de vacature staat een sluitingsdatum"
    static func useDeadline(_ date: Date) -> String {
        "Gebruik \(date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "nl_NL")))) als deadline"
    }
    static let addToCalendar = "Zet in je agenda"
    static func calendarTitle(_ vacancy: Vacancy) -> String { "Deadline sollicitatie \(vacancy.title) bij \(vacancy.company)" }
    static let calendarNotes = "Bijgehouden in PAVE."

    // The applications
    static let applicationsEmptyTitle = "Nog geen sollicitaties"
    static let applicationsEmpty = "Tik bij een vacature op Solliciteren, of maak er zelf een. Hier houd je bij hoe het ermee staat."
    static func letterSubject(_ vacancy: Vacancy) -> String {
        vacancy.isOpenApplication ? "Betreft: open sollicitatie" : "Betreft: sollicitatie \(vacancy.title)"
    }

    // Your own application
    static let newApplication = "Nieuwe sollicitatie"
    static let somethingWrong = "Dat lukte niet"
    static let shareApplication = "Deel je sollicitatie"
    static let theVacancy = "De vacature"
    static let showMore = "Lees meer"
    static let showLess = "Minder"
    static let deleteApplication = "Verwijder sollicitatie"
    static func deleteApplicationQuestion(_ company: String) -> String { "Sollicitatie bij \(company) verwijderen?" }
    static let deleteApplicationHint = "Je cv, brief en wat je bijhield gaan weg van deze iPhone. Wat je al deelde, beheer je bij Profiel."
    static let openFailed = "Je kluis kon niet worden geladen, dus je cv zou leeg blijven. Probeer het zo opnieuw."
    static let newApplicationIntro = "Voor een vacature die je zelf vond, of een open sollicitatie bij een bedrijf. Daarna kies je een ontwerp voor je cv en brief."
    static let ownCompany = "Bedrijf"
    static let ownCompanyPrompt = "Bijvoorbeeld Albert Heijn"
    static let ownCompanyMissing = "Vul het bedrijf in."
    static let ownTitle = "Functie"
    static let ownTitlePrompt = "Leeg laten voor een open sollicitatie"
    static let ownCity = "Plaats"
    static let ownCityPrompt = "Bijvoorbeeld Eindhoven"
    static let ownLink = "Link naar de vacature"
    static let ownLinkPrompt = "Bijvoorbeeld werkenbij.ah.nl/…"
    static let ownLinkBad = "Dit lijkt geen link. Controleer hem of laat het veld leeg."
    static let ownText = "Tekst van de vacature"
    static let ownTextPrompt = "Plak hier de vacature, dan kan Ayla je brief erop afstemmen"
    static let ownTextNote = "Alleen voor jouw cv en brief. PAVE stuurt niets naar het bedrijf."
    static let ownStart = "Maak cv en brief"
    static func statusCount(_ status: ApplicationStatus, _ count: Int) -> String { "\(Self.status(status)) · \(count)" }
    static func changedOn(_ date: Date) -> String {
        "Gewijzigd op \(date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "nl_NL"))))"
    }

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
    static let aylaUnavailable = "Ayla is nu niet bereikbaar. Je kunt alles zelf invullen."
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
