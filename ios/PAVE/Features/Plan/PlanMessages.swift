import PAVECore

/// The words of the plans, the same as in docs/ui-teksten.md.
enum PlanMessages {
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
