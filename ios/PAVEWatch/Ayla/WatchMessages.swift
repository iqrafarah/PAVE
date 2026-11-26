import PAVECore

/// The texts on the Watch: short, because they have to fit on the wrist.
enum WatchMessages {
    static let tapToTalk = "Tik op Ayla en praat"
    static let listening = "Ik luister…"
    static let listeningAgain = "Nog iets? Ik luister…"
    static let speaking = "Ayla praat"
    static let tapToAskAgain = "Tik op Ayla voor een nieuwe vraag"
    static let understanding = "Even verstaan…"
    static let thinking = "Even denken…"
    static let nothingHeard = "Ik hoorde niets. Probeer het nog een keer."
    static let noMicrophone = "Zet de microfoon aan voor PAVE in Instellingen op je Apple Watch."
    static let signedOutTitle = "Log in op je iPhone"
    static let signedOutMessage = "Open PAVE op je iPhone en log in. Dan kun je hier met Ayla praten."
    static let notConnectedTitle = "Koppel je Watch"
    static let notConnectedMessage = "Open PAVE op je iPhone en kies Instellingen › Ingelogde apparaten."
    static let rememberQuestion = "Zal ik dit onthouden?"
    static let remembered = "Onthouden"
    static let notRemembered = "Niet onthouden"

    static func message(for error: AylaError) -> String {
        switch error {
        case .noConnection: "Geen verbinding. Probeer het zo nog eens."
        case .notSetUp: "Praten met Ayla kan nog niet op je Apple Watch."
        case .notSignedIn, .insufficientAssurance: signedOutMessage
        case .conversationNotFound, .unavailable: "Ayla is even niet bereikbaar. Probeer het zo nog eens."
        }
    }
    static let handoffDone = "Klaar op je iPhone."
    static let handoffQueued = "Gaat mee zodra je iPhone in de buurt is."
    static func coachQuestion(_ company: String) -> String {
        "Ik heb zo een gesprek bij \(company). Geef me drie korte punten om te noemen, elk één zin, op basis van wat je van mij weet."
    }
    static let coachTitle = "Gesprek-coach"
    static let coachBreathe = "Adem rustig mee"
    static let coachIn = "In…"
    static let coachHold = "Vast…"
    static let coachOut = "Uit…"
    static let coachPoints = "Om te noemen"
    static let coachThinking = "Ayla zoekt je punten…"
    static let coachFailed = "Ayla kon nu geen punten geven. Probeer het op je iPhone."
    static let coachGo = "Je bent er klaar voor."
}
