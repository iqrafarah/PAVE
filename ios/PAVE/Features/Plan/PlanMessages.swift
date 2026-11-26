import Foundation
import PAVECore

/// The words of the plans, the same as in docs/ui-teksten.md.
enum PlanMessages {
    static let folded = "Ingeklapt"
    static let unfolded = "Uitgeklapt"
    /// Under a step: its deadline and the evidence that shows it, such as "Voor 15 dec. · 1 bewijsstuk".
    static func stepExtras(_ step: PavePlanStep) -> String? {
        var parts: [String] = []
        if let due = step.due.flatMap(VaultDay.init), let date = Calendar.current.date(from: DateComponents(year: due.year, month: due.month, day: due.day)) {
            parts.append("Voor \(date.formatted(.dateTime.day().month(.abbreviated).locale(PaveLanguageStore.current.locale)))".translated)
        }
        let count = step.evidenceIDs.count
        if count > 0 { parts.append((count == 1 ? "1 bewijsstuk" : "\(count) bewijsstukken").translated) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// A deadline that passed on a step that is not done.
    static func isOverdue(_ step: PavePlanStep, now: Date = .now) -> Bool {
        guard step.status != .done, step.status != .skipped, let due = step.due.flatMap(VaultDay.init),
              let date = Calendar.current.date(from: DateComponents(year: due.year, month: due.month, day: due.day + 1)) else { return false }
        return date < now
    }

    static let title = "Plan"
    static let emptyTitle = "Je hebt nog geen plan"
    static let emptyMessage = "Maak een plan voor een doel waar je naartoe wilt werken. Ayla helpt je stap voor stap."
    static let newPlan = "Nieuw plan"
    static let create = "Maken"
    static let edit = "Plan aanpassen"
    static let rename = "Naam aanpassen"
    static let nameLabel = "Naam"
    static let namePlaceholder = "Bijvoorbeeld: Doorgroeien naar teamleider"
    static let goalLabel = "Doel"
    static let goalHint = "Waar wil je naartoe werken? Ayla gebruikt dit in de gesprekken van dit plan."
    static let goalPlaceholder = "Wat wil je bereiken?"
    static let startLabel = "Beginnen met"
    static let delete = "Plan verwijderen"
    static let deleteQuestion = "Plan verwijderen?"
    static let deleteBody = "De stappen van dit plan verdwijnen. Bewijs in je kluis blijft altijd bewaard."
    static let deleteKeepChats = "Verwijderen, gesprekken bewaren"
    static let deleteWithChats = "Verwijderen met gesprekken"
    static let complete = "Voltooien"
    static let reopen = "Weer openen"
    static let activeSection = "Actief"
    static let finishedSection = "Voltooid"

    static func deleteBody(chats: Int) -> String {
        let chats = chats == 1 ? "het gesprek" : "de \(chats) gesprekken"
        return "Wil je \(chats) met Ayla van dit plan bewaren? Ze komen dan in je gewone chats. Bewijs in je kluis blijft altijd bewaard."
    }
    static let saveFailed = "Je plan kon niet worden bewaard. Probeer het nog eens."
    static let loadFailed = "Je plannen konden niet worden geladen."
    static let notAvailable = "Plannen zijn nog niet beschikbaar. Probeer het later nog eens."
    static let kindLabel = "Soort stap"
    static let skippedNote = "Overgeslagen stappen tellen niet mee."

    static let steps = "Stappen"
    static let noSteps = "Dit plan heeft nog geen stappen."
    static let addStep = "Stap toevoegen"
    static let proposeSteps = "Laat Ayla stappen voorstellen"
    static let proposalTitle = "Voorstel van Ayla"
    static let proposalThinking = "Ayla denkt na over je stappen…"
    static let proposalFailed = "Ayla kon nu geen stappen voorstellen. Probeer het opnieuw."
    static let proposalAgain = "Probeer opnieuw"
    static let proposalOthers = "Andere stappen voorstellen"
    static let proposalEmpty = "Ayla heeft geen nieuwe stappen voor dit plan. Vul je doel aan en probeer het opnieuw, of voeg zelf een stap toe."
    static func proposalAdd(_ count: Int) -> String { count == 1 ? "Voeg 1 stap toe" : "Voeg \(count) stappen toe" }
    static func proposalReads(evidence: Int, hasVacancy: Bool) -> String {
        let seen = evidence == 0
            ? "Ze ziet geen bewijs uit je kluis: daar gaf je geen toestemming voor."
            : "Van je kluis ziet ze alleen de titels van de \(evidence == 1 ? "1 bewijsstuk" : "\(evidence) bewijsstukken") die ze mag bekijken."
        return "Ayla gebruikt de naam en het doel van je plan\(hasVacancy ? " en de vacature waar het om gaat" : ""). \(seen) Er wordt niets toegevoegd tot jij kiest."
    }
    static let vacancyPlanMake = "Maak een plan voor deze vacature"
    static let vacancyPlanOpen = "Open je plan voor deze vacature"
    static func vacancyPlanHint(_ missing: Int) -> String {
        missing == 0
            ? "Stappen van de vacature lezen tot het gesprek oefenen."
            : "Met een stap voor \(missing == 1 ? "wat je nog mist" : "elk van de \(min(missing, 3)) dingen die je nog mist"), je cv en brief, en het gesprek."
    }
    static let openApplication = "Open cv en brief"
    static let practiseTalk = "Oefen het gesprek met Ayla"
    static let project = "Project"
    static let compassTitle = "Skill-kompas"
    static func compassIntro(_ count: Int) -> String { "Over \(count == 1 ? "de vacature" : "de \(count) vacatures") die je vond, bewaarde of waarop je solliciteert: wat ze vragen, wat je al kunt laten zien en wat je nog mist." }
    static let compassNext = "Hier haal je het meest uit"
    static func compassAskedIn(_ count: Int, of total: Int) -> String { "Gevraagd in \(count) van de \(total) vacatures, en nog niet in je kluis." }
    static func compassCount(_ count: Int, of total: Int) -> String { "\(count) van \(total)" }
    static let compassMissing = "Wat je nog mist"
    static let compassHave = "Wat je al kunt laten zien"
    static let compassMatchedOnly = "Past volgens de vacature; zet er bewijs van in je kluis."
    static func compassProof(_ titles: [String], verified: Bool) -> String { (verified ? "Geverifieerd: " : "Bewijs: ") + titles.prefix(2).joined(separator: ", ") }
    static let compassToPlan = "Zet in een plan"
    static let compassAdded = "In je plan"
    static let compassNewPlan = "Nieuw plan"
    static let compassAsk = "Vraag Ayla"
    static func compassStep(_ skill: String) -> String { String("Werk aan \(skill)".prefix(80)) }
    static func compassStepSummary(_ count: Int) -> String { count == 1 ? "Een vacature die je bekeek vraagt hierom." : "\(count) vacatures die je bekeek vragen hierom." }
    static let compassEmptyTitle = "Nog geen vacatures"
    static let compassEmpty = "Zoek of bewaar vacatures met Ayla. Dan zie je hier wat ze vragen en wat je nog mist."
    static func compassCardHint(_ skill: String, count: Int, of total: Int) -> String { "Meest gevraagd wat je mist: \(skill) (\(count) van \(total))" }
    static let compassCardAllSet = "Wat de vacatures vragen en wat je al kunt laten zien"
    static let noProject = "Geen project"
    static let linkProject = "Koppel aan een project"
    static let linkProjectHint = "De gesprekken van dit plan komen dan in dat project en gebruiken de instructies en bronnen ervan."
    static let linkedProjectHint = "De gesprekken van dit plan staan in dit project en gebruiken de instructies en bronnen ervan."
    static let projectPlan = "Plan in dit project"
    static let projectPlans = "Plannen in dit project"
    static let withAylaTitle = "Stappen van Ayla"
    static let withAylaSummary = "Ayla stelt stappen voor bij je doel. Jij kiest welke je houdt."
    static let stepTitleLabel = "Stap"
    static let stepTitlePlaceholder = "Wat ga je doen?"
    static let stepSummaryLabel = "Omschrijving"
    static let stepSummaryPlaceholder = "Een korte uitleg (mag leeg blijven)"
    static let editStep = "Stap aanpassen"
    static let deleteStep = "Stap verwijderen"
    static let markDone = "Afronden"
    static let markActive = "Hier verder"
    static let markUpcoming = "Nog te doen"
    static let markSkipped = "Overslaan"
    static let discussStep = "Bespreken met Ayla"
    static let openStepChat = "Gesprek van deze stap openen"
    static let detachConversation = "Uit plan halen"
    static let attachPlan = "Plan toevoegen"
    static let followOnLockScreen = "Volg op toegangsscherm"
    static let stopFollowing = "Niet meer volgen"
    static let showNamesOnLockScreen = "Naam en stap tonen"
    static let lockScreenSection = "Toegangsscherm en Dynamic Island"
    static let choosePlan = "Kies een plan"
    static let choosePlanHint = "Ayla helpt je in deze chat met de stappen van het plan."
    static let noPlanForChat = "Geen plan"

    static func inPlan(_ name: String) -> String {
        "Nu: \(name)"
    }
    static let finished = "Klaar! Je hebt alle stappen afgerond."
    static let stepFinished = "Stap afgerond"

    static let conversations = "Gesprekken met Ayla"
    static let noConversations = "Nog geen gesprekken in dit plan."
    static let newConversation = "Nieuw gesprek"
    static let resume = "Verder met Ayla"
    static let openPlan = "Open plan"
    static let showSteps = "Tik om de stappen te zien"
    static let islandHint = "Tik of veeg omlaag voor de stappen, houd vast om het plan te openen"
    static let hideSteps = "Tik om de stappen te verbergen"

    static func progress(_ plan: PavePlan) -> String {
        "\(plan.doneCount) van \(plan.totalCount)"
    }

    static func stepNumber(_ plan: PavePlan) -> String {
        "Stap \(plan.currentNumber) van \(plan.totalCount)"
    }

    /// "2/6": done of the steps that count, for the pill.
    static func shortProgress(_ plan: PavePlan) -> String {
        "\(plan.doneCount)/\(plan.totalCount)"
    }

    static func stepCount(_ count: Int) -> String {
        count == 1 ? "1 stap" : "\(count) stappen"
    }

    static func conversationCount(_ count: Int) -> String {
        count == 1 ? "1 gesprek" : "\(count) gesprekken"
    }

    static func status(_ status: PavePlanStep.Status) -> String {
        switch status {
        case .upcoming: "nog te doen"
        case .active: "nu bezig"
        case .done: "afgerond"
        case .skipped: "overgeslagen"
        }
    }

    /// What the text field says when a chat starts for one step.
    static func stepPrompt(_ step: PavePlanStep) -> String {
        "Help me met de stap \"\(step.title)\"."
    }

    static func untitledConversation(_ index: Int) -> String {
        "Gesprek \(index)"
    }
}
