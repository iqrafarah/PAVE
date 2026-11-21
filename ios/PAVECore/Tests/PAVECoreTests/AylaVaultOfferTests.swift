import Foundation
import Testing
@testable import PAVECore

struct AylaVaultOfferTests {
    @Test func anOpenQuestionOfHerOwnGetsNoJaAndNee() {
        let asked = "Kunnen we iets toevoegen aan mijn kluis?"
        let open = AylaReply(id: "r", conversationId: "c", text: "Wat wil je toevoegen aan je kluis? Bijvoorbeeld een diploma of een stage.")
        #expect(AylaVaultOffer.question(for: open, asked: asked) == nil)
        #expect(!AylaVaultOffer.offersToAddEvidence(open, asked: asked))
        let yesNo = AylaReply(id: "r", conversationId: "c", text: "Ik zie geen stage in je kluis. Zal ik hem toevoegen?")
        #expect(AylaVaultOffer.question(for: yesNo, asked: asked)?.text == "")
        #expect(AylaVaultOffer.question(for: yesNo, asked: asked)?.choices.map(\.label) == ["Ja", "Nee"])
        #expect(AylaVaultOffer.offersToAddEvidence(yesNo, asked: asked))
        let plain = AylaReply(id: "r", conversationId: "c", text: "Ik zie geen stage in je kluis.")
        #expect(AylaVaultOffer.question(for: plain, asked: asked)?.text == "Wil je iets toevoegen?")
        #expect(AylaVaultOffer.lastQuestion(in: "Mooi.\nWelke stage was dat?") == .open)
        #expect(AylaVaultOffer.lastQuestion(in: "Wat een stage. Zal ik hem toevoegen?") == .yesNo)
    }

    @Test func afterNoTheAppDoesNotOfferItAgain() {
        let reply = AylaReply(id: "r", conversationId: "c", text: "Prima. Ik zie geen stage in je kluis.")
        #expect(AylaVaultOffer.question(for: reply, asked: "Kunnen we iets toevoegen aan mijn kluis?") != nil)
        #expect(AylaVaultOffer.question(for: reply, asked: "Nee") == nil)
        #expect(AylaVaultOffer.question(for: reply, asked: "Nee, liever niet") == nil)
        #expect(!AylaVaultOffer.offersToAddEvidence(reply, asked: "Nee"))
    }

    @Test func aConsentQuestionInWordsDoesNotOpenAddingEvidence() {
        let choices = [AylaReply.Choice(id: "y", label: "Ja"), AylaReply.Choice(id: "n", label: "Nee")]
        let consent = AylaReply(
            id: "r", conversationId: "c", text: "Wat wil je toevoegen aan je kluis?",
            question: AylaReply.Question(text: "Mag ik in je kluis kijken om te zien wat je al hebt?", choices: choices)
        )
        #expect(!AylaVaultOffer.offersToAddEvidence(consent, asked: "Kunnen we iets toevoegen aan mijn kluis?"))
        let offer = AylaReply(id: "r", conversationId: "c", text: "Ik zie je stage niet in je kluis.", question: AylaReply.Question(text: "Wil je hem toevoegen?", choices: choices))
        #expect(AylaVaultOffer.offersToAddEvidence(offer, asked: "Staat mijn stage erin?"))
    }

    @Test func aQuestionAlreadyInTheTextIsNotAskedAgain() {
        #expect(AylaVaultOffer.isAlreadyAsked("Mag ik in je kluis kijken om je diploma te zoeken?", in: "Mag ik in je kluis kijken om je diploma te zoeken"))
        #expect(AylaVaultOffer.isAlreadyAsked("Wil je iets toevoegen?", in: "Ik zie het niet. Wil je iets toevoegen?"))
        #expect(!AylaVaultOffer.isAlreadyAsked("Wil je iets toevoegen?", in: "Ik zie het niet."))
        #expect(!AylaVaultOffer.isAlreadyAsked("", in: "Hoi"))
    }

    private func reply(_ text: String, question: AylaReply.Question? = nil, navigation: AylaScreen? = nil, action: AylaActionKind? = nil, blocks: [AylaBlock] = []) -> AylaReply {
        AylaReply(
            id: "r",
            conversationId: "c",
            text: text,
            question: question,
            proposedAction: action.map { AylaReply.ProposedAction(id: "a", kind: $0, summary: "", expiresAt: .distantFuture) },
            blocks: blocks,
            navigation: navigation.map { AylaReply.Navigation(screen: $0) }
        )
    }

    @Test func askingWhatIsInTheVaultOffersNothingAskingToAddDoes() {
        let found = reply("Je propedeuse HBO-ICT staat in je kluis, bevestigd door Fontys.")
        #expect(AylaVaultOffer.question(for: found, asked: "Kun je mijn diploma zoeken in de kluis?") == nil)
        #expect(!AylaVaultOffer.offersToAddEvidence(found, asked: "Kun je mijn diploma zoeken in de kluis?"))
        #expect(AylaVaultOffer.question(for: reply("Ik zie niets in je kluis over Scrum."), asked: "Wat weet je over Scrum?") == nil)

        let add = reply("Goed idee.")
        #expect(AylaVaultOffer.question(for: add, asked: "Zet mijn stage in de kluis") == AylaVaultOffer.question)
        #expect(AylaVaultOffer.offersToAddEvidence(add, asked: "Kan ik mijn certificaat aan de kluis toevoegen?"))
    }

    @Test func herQuestionWhetherSheMayLookInTheVaultIsNoOffer() {
        let ask = AylaReply.Question(text: "Mag ik in je kluis kijken om je diploma te zoeken?", choices: [.init(id: "yes", label: "Ja"), .init(id: "no", label: "Nee")])
        var answer = reply("Ik zoek hem voor je op.", question: ask)
        answer.accessRequest = AylaReply.AccessRequest(id: "a", purpose: "je diploma te zoeken", categories: [])
        #expect(AylaVaultOffer.question(for: answer, asked: "Zoek mijn diploma in de kluis") == ask)
        #expect(!AylaVaultOffer.offersToAddEvidence(answer, asked: "Zet mijn diploma in de kluis"))
    }

    @Test func openingTheVaultOrAnOrdinaryAnswerAsksNothing() {
        #expect(AylaVaultOffer.question(for: reply("Ik open je kluis."), asked: "Open mijn kluis") == nil)
        #expect(AylaVaultOffer.question(for: reply("Front-end past goed bij je."), asked: "Welke richting past bij mij?") == nil)
        #expect(!AylaVaultOffer.offersToAddEvidence(reply("Front-end past goed bij je."), asked: "Welke richting past bij mij?"))
        #expect(AylaVaultOffer.question(for: nil, asked: "") == nil)
    }

    @Test func herOwnQuestionComesFirstAndCountsWhenItIsAboutAdding() {
        let own = AylaReply.Question(text: "Zal ik dit in je kluis zetten?", choices: [.init(id: "1", label: "Ja, graag"), .init(id: "2", label: "Nee")])
        let answer = reply("Mooi project!", question: own)
        #expect(AylaVaultOffer.question(for: answer, asked: "Ik maakte een app") == own)
        #expect(AylaVaultOffer.offersToAddEvidence(answer, asked: "Ik maakte een app"))
        let other = AylaReply.Question(text: "Wil je meer weten?", choices: [.init(id: "1", label: "Ja"), .init(id: "2", label: "Nee")])
        #expect(!AylaVaultOffer.offersToAddEvidence(reply("Over Scrum.", question: other), asked: "Wat is Scrum?"))
    }

    @Test func navigationOrAProposalAlwaysOffers() {
        #expect(AylaVaultOffer.offersToAddEvidence(reply("Zal ik het toevoegen?", navigation: .addEvidence), asked: ""))
        // Her text already asks it: Ja and Nee without the question a second time; without a question of her own, the fixed one.
        #expect(AylaVaultOffer.question(for: reply("Zal ik het toevoegen?", navigation: .addEvidence), asked: "")?.text == "")
        #expect(AylaVaultOffer.question(for: reply("Ik zie het niet.", navigation: .addEvidence), asked: "") == AylaVaultOffer.question)
        #expect(AylaVaultOffer.offersToAddEvidence(reply("Ik zet je stage klaar.", action: .addVaultItem), asked: ""))
    }

    @Test func whatCountsAsYesAndWhichSkillsShePicked() {
        let putIt = reply("Zo zet ik het in je kluis: Stage. Zal ik deze stage zo in je kluis zetten?")
        let detail = reply("Zo zet ik het in je kluis: Stage. Klopt de periode van maart tot augustus?")
        #expect(AylaVaultOffer.asksToPutInVault(putIt))
        #expect(!AylaVaultOffer.asksToPutInVault(detail))
        #expect(AylaVaultOffer.isConfirmation("Zet er maar in"))
        #expect(AylaVaultOffer.isConfirmation("Graag"))
        #expect(AylaVaultOffer.isConfirmation("Ja dat klopt!"))
        #expect(!AylaVaultOffer.isConfirmation("Ja, maar eerst de datum aanpassen"))
        #expect(!AylaVaultOffer.isConfirmation("Nee"))
        #expect(!AylaVaultOffer.isConfirmation("Ja? Wat bedoel je"))
        #expect(!AylaVaultOffer.isConfirmation("Wat staat erin"))
        #expect(AylaVaultOffer.isYes("Ja"))
        #expect(AylaVaultOffer.isYes(" ja, graag"))
        #expect(AylaVaultOffer.isYes("Toevoegen"))
        #expect(!AylaVaultOffer.isYes("Nee"))
        #expect(!AylaVaultOffer.isYes("Jammer genoeg niet"))
        let blocks: [AylaBlock] = [
            .skillSuggestions(itemId: "i", skills: [.init(name: " Scrum ", reason: ""), .init(name: "Presenteren", reason: "")]),
            .skillSuggestions(itemId: "j", skills: [.init(name: "Scrum", reason: ""), .init(name: "", reason: "")]),
        ]
        #expect(AylaVaultOffer.suggestedSkills(in: reply("", blocks: blocks)) == ["Scrum", "Presenteren"])
    }
}

struct AylaScreenRequestTests {
    @Test func aShortRequestOpensThatPage() {
        #expect(AylaScreenRequest.screen(askedIn: "Open mijn kluis") == .vault)
        #expect(AylaScreenRequest.screen(askedIn: "ga naar mijn plan") == .plans)
        #expect(AylaScreenRequest.screen(askedIn: "Breng me naar mijn profiel") == .profile)
    }

    @Test func everydayWaysOfAskingOpenThePage() {
        let asked: [(String, AylaScreen)] = [
            ("Open instellingen", .settings), ("open m’n kluis even", .vault), ("Kun je mijn kluis openen?", .vault),
            ("Laat mijn plan zien", .plans), ("Laat me mijn profiel zien", .profile), ("Ik wil naar mijn instellingen", .settings),
            ("Naar de kluis", .vault), ("Kluis", .vault), ("Mijn meldingen", .notifications), ("Toon mijn notificaties", .notifications),
            ("Bekijk mijn plannen", .plans), ("Mag ik mijn profiel zien?", .profile), ("Instellingen openen", .settings),
            ("Ga even naar mijn kluis", .vault), ("Open de settings", .settings),
        ]
        for (text, screen) in asked {
            #expect(AylaScreenRequest.screen(askedIn: text) == screen, "\(text)")
        }
    }

    @Test func aPageThatIsOnlyMentionedDoesNotOpen() {
        let asked = [
            "Toon vacatures die bij mijn profiel passen", "Kijk naar mijn plan en zeg wat beter kan", "Kun je mijn kluis zien?",
            "Zet mijn stage in de kluis", "Open een nieuw plan", "Ik ben benieuwd naar mijn plan", "Open de kluis niet",
            "Ga mijn plan maken", "Sluit de kluis",
        ]
        for text in asked {
            #expect(AylaScreenRequest.screen(askedIn: text) == nil, "\(text)")
        }
    }

    @Test func yesToHerOfferOpensThePage() {
        let choices = [AylaReply.Choice(id: "y", label: "Ja"), AylaReply.Choice(id: "n", label: "Nee")]
        let inWords = AylaReply(id: "r", conversationId: "c", text: "Wil je naar je instellingen gaan?")
        #expect(AylaScreenRequest.screen(confirmedBy: "Graag", after: inWords)?.screen == .settings)
        #expect(AylaScreenRequest.screen(confirmedBy: "Nee", after: inWords) == nil)
        let pointed = AylaReply(
            id: "r", conversationId: "c", text: "Je eindstage staat in je kluis.",
            question: AylaReply.Question(text: "Zal ik hem openen?", choices: choices), navigation: AylaReply.Navigation(screen: .vaultItem, itemId: "i")
        )
        #expect(AylaScreenRequest.screen(confirmedBy: "Ja", after: pointed) == AylaReply.Navigation(screen: .vaultItem, itemId: "i"))
        let evidence = AylaReply(
            id: "r", conversationId: "c", text: "Ik zie je stage niet in je kluis.",
            question: AylaReply.Question(text: "Wil je hem toevoegen?", choices: choices), navigation: AylaReply.Navigation(screen: .addEvidence)
        )
        #expect(AylaScreenRequest.screen(confirmedBy: "Ja", after: evidence) == nil)
        #expect(AylaScreenRequest.screen(confirmedBy: "Ja", after: AylaReply(id: "r", conversationId: "c", text: "Je kluis is leeg.")) == nil)
    }

    @Test func onlyOpeningNeedsNoAnswer() {
        #expect(AylaScreenRequest.screenOnlyAsked(in: "Open kluis") == .vault)
        #expect(AylaScreenRequest.screenOnlyAsked(in: "Hey Ayla, kun je mijn instellingen openen?") == .settings)
        #expect(AylaScreenRequest.screenOnlyAsked(in: "Meldingen") == .notifications)
        #expect(AylaScreenRequest.screenOnlyAsked(in: "Open instellingen en zet donker aan") == nil)
        #expect(AylaScreenRequest.screenOnlyAsked(in: "Open mijn kluis en zoek mijn stage") == nil)
        #expect(AylaScreenRequest.screenOnlyAsked(in: "Wat staat er in mijn kluis?") == nil)
    }

    @Test func onlyPagesTheBrainKnowsGoAlongAsContext() {
        #expect(!AylaScreenRequest.knownToBrain.contains(.notifications))
        #expect(AylaScreenRequest.knownToBrain.contains(.settings))
    }

    @Test func aQuestionAboutThePageDoesNot() {
        #expect(AylaScreenRequest.screen(askedIn: "Wat staat er in mijn kluis?") == nil)
        #expect(AylaScreenRequest.screen(askedIn: "Kun je een plan voor me maken waarin ik open en eerlijk leer communiceren met collega's op mijn stage?") == nil)
    }
}

struct AylaAppCommandTests {
    private let folders = [AylaAppCommand.Named(id: "f1", name: "Stages"), .init(id: "f2", name: "Diploma’s")]
    private let items = [AylaAppCommand.Named(id: "i1", name: "Eindstage bij Philips"), .init(id: "i2", name: "Scrum-certificaat")]

    private func command(_ text: String, inSettings: Bool = false) -> AylaAppCommand? {
        AylaAppCommand.command(in: text, folders: folders, items: items, inSettings: inSettings)
    }

    @Test func changesTheAppearance() {
        #expect(command("Zet het thema op blauw") == .theme(.blue))
        #expect(command("Maak het paars") == .theme(.purple))
        #expect(command("Kies groen") == .theme(.green))
        #expect(command("Thema groen") == .theme(.green))
        #expect(command("Kun je het thema rood maken?") == .theme(.red))
        #expect(command("Open instellingen en zet het thema op goud") == .theme(.gold))
        #expect(command("Wil je de themakleur op oranje zetten alsjeblieft") == .theme(.orange))
        #expect(command("Maak de tekst groter") == .textSizeStep(1))
        #expect(command("De letters mogen kleiner") == .textSizeStep(-1))
        #expect(command("Zet de tekst op groot") == .textSize(.large))
        #expect(command("Tekstgrootte standaard") == .textSize(.standard))
        #expect(command("Toon mijn kluis als lijst") == .vaultLayout(.list))
        #expect(command("Kluisweergave raster") == .vaultLayout(.grid))
        #expect(command("Zet tekst bij praten uit") == .voiceText(false))
        #expect(command("Tekst bij praten aan") == .voiceText(true))
        #expect(command("Maak mijn chats vindbaar, aan") == .chatsInSearch(true))
        #expect(command("Chats niet vindbaar in iPhone-zoeken") == .chatsInSearch(false))
        #expect(command("Zet donkere modus aan") == .displayMode(.dark))
        #expect(command("Donkere modus uit") == .displayMode(.light))
        #expect(command("Maak het donker") == .displayMode(.dark))
        #expect(command("Licht of donker automatisch") == .displayMode(.auto))
    }

    @Test func goesSomewhere() {
        #expect(command("Open weergave") == .settingsPage(.appearance))
        #expect(command("Ga naar ingelogde apparaten") == .settingsPage(.devices))
        #expect(command("Laat privacy zien") == .settingsPage(.privacy))
        #expect(command("Open mijn archief") == .settingsPage(.archive))
        #expect(command("Ga naar gegevens bewaren") == .settingsPage(.retention))
        #expect(command("Open de map stages") == .vaultFolder(id: "f1"))
        #expect(command("Open diploma's") == .vaultFolder(id: "f2"))
        #expect(command("Laat eindstage bij philips zien") == .vaultItem(id: "i1"))
        #expect(command("Selecteer scrum-certificaat") == .vaultItem(id: "i2"))
        #expect(command("Kun je het bewijs Scrum-certificaat openen") == .vaultItem(id: "i2"))
        #expect(command("Bewaar deze vacature") == .saveVacancy(nil))
        #expect(command("Bewaar de tweede") == .saveVacancy(1))
        #expect(command("Bewaar vacature 3") == .saveVacancy(2))
        #expect(command("Sla de laatste vacature op") == .saveVacancy(-1))
        #expect(command("Bewaar hem") == .saveVacancy(nil))
        #expect(command("Open mijn bewaarde vacatures") == .openSavedVacancies)
        #expect(command("Bewaarde vacatures") == .openSavedVacancies)
        #expect(command("Open de tweede vacature") == .openVacancy(1))
        #expect(command("Laat vacature 3 zien") == .openVacancy(2))
        #expect(command("Bekijk de laatste vacature") == .openVacancy(-1))
        #expect(command("Toon de vacatures") == .openVacancies)
        #expect(command("Kun je de vacatures weer openen") == .openVacancies)
        #expect(command("Ga terug") == .back)
        #expect(command("Terug") == .back)
        #expect(command("Sluit maar") == .close)
        #expect(command("Sluit de instellingen") == .close)
    }

    @Test func choosingYourselfIsHeardInYourOwnWords() {
        for said in ["Kies zelf", "Laat mezelf kiezen", "Ik kies zelf", "Laat mij zelf kiezen.", "Ik wil het zelf bepalen", "Zelf kiezen",
                     "Laat mij kiezen", "Ik wil zelf selecteren welke", "Nee, ik kies zelf", "Ja maar ik kies zelf wat je ziet", "Mijn eigen keuze"] {
            #expect(AylaVaultOffer.wantsToChoose(said), "\(said)")
        }
        for said in ["Ja", "Nee", "Ik wil niet zelf kiezen", "Kies jij maar", "Zoek vacatures als developer", "Welke kies jij?", ""] {
            #expect(!AylaVaultOffer.wantsToChoose(said), "\(said)")
        }
    }

    @Test func twoThingsInOneSentenceGoToAylasBrain() {
        #expect(command("Zet donkere modus aan en open mijn stages") == nil)
        #expect(command("Maak het thema blauw en zet de tekst groter") == nil)
        #expect(command("Open de map stages en daarna mijn diploma's") == nil)
        #expect(command("Zet de donkere modus aan") == .displayMode(.dark))
        #expect(command("Open de map stages") == .vaultFolder(id: "f1"))
    }

    @Test func anActionFromAylaBecomesWhatTheAppAlreadyDoes() {
        let folders = [AylaAppCommand.Named(id: "f1", name: "Stages"), AylaAppCommand.Named(id: "f2", name: "Diploma’s")]
        #expect(AylaAppAction("setDisplayMode", value: "dark").command() == .displayMode(.dark))
        #expect(AylaAppAction("setTheme", value: "blue").command() == .theme(.blue))
        #expect(AylaAppAction("setTheme", value: "custom").command() == nil)
        #expect(AylaAppAction("setTextSize", value: "bigger").command() == .textSizeStep(1))
        #expect(AylaAppAction("setTextSize", value: "large").command() == .textSize(.large))
        #expect(AylaAppAction("setVoiceText", value: "off").command() == .voiceText(false))
        #expect(AylaAppAction("openSettingsPage", value: "privacy").command() == .settingsPage(.privacy))
        #expect(AylaAppAction("openFolder", target: "de map stages").command(folders: folders) == .vaultFolder(id: "f1"))
        #expect(AylaAppAction("openFolder", target: "diplomas").command(folders: folders) == .vaultFolder(id: "f2"))
        #expect(AylaAppAction("openFolder", target: "Certificaten").command(folders: folders) == nil)
        #expect(AylaAppAction("openVacancy", value: "2").command() == .openVacancy(1))
        #expect(AylaAppAction("saveVacancy", value: "last").command() == .saveVacancy(-1))
        #expect(AylaAppAction("newChat").command() == nil)
    }

    @Test func aNameFindsTheClosestThingOrNothingWhenItIsUnclear() {
        let items = [
            AylaAppCommand.Named(id: "1", name: "Eindstage bij Philips"), AylaAppCommand.Named(id: "2", name: "Stage LiveWall"),
            AylaAppCommand.Named(id: "3", name: "Scrum-certificaat"), AylaAppCommand.Named(id: "4", name: "Scrum"),
        ]
        #expect(AylaAppAction.best("eindstage", in: items)?.id == "1")
        #expect(AylaAppAction.best("mijn stage bij livewall", in: items)?.id == "2")
        #expect(AylaAppAction.best("Scrum", in: items)?.id == "4")
        #expect(AylaAppAction.best("scrum certificaat", in: items)?.id == "3")
        #expect(AylaAppAction.best("diploma", in: items) == nil)
        #expect(AylaAppAction.best("s", in: items) == nil)
    }

    @Test func actionsComeWithTheReplyAndABrokenOneDoesNotBreakIt() throws {
        let json = #"{"version":1,"id":"r","conversationId":"c","text":"Zal ik je uitloggen?","blocks":[],"usedData":[],"actions":[{"do":"signOut","confirm":true},{"do":"setChatExpiry","value":"7"}]}"#
        let reply = try AylaReply.decode(Data(json.utf8))
        #expect(reply.actions == [AylaAppAction("signOut", confirm: true), AylaAppAction("setChatExpiry", value: "7")])
        #expect(reply.actions?.first?.needsConfirmation == true)
        #expect(reply.actions?.last?.expiry == .days(7))
        #expect(AylaAppAction("setChatExpiry", value: "never").expiry == .never)
        #expect(AylaAppAction("setChatExpiry", value: "default").expiry == .followsAccount)
        #expect(AylaAppAction("setMemory", value: "aan").isOn == true)
    }

    @Test func askingAboutVacanciesStaysAQuestionForAyla() {
        #expect(command("Zoek vacatures als developer in Eindhoven") == nil)
        #expect(command("Toon nieuwe vacatures") == nil)
        #expect(command("Wat vind je van de tweede vacature") == nil)
        #expect(command("Past de eerste vacature bij mij") == nil)
    }

    @Test func oneWordOnlyCountsOnThePageItself() {
        #expect(command("Privacy") == nil)
        #expect(command("Roze") == nil)
        #expect(command("Privacy", inSettings: true) == .settingsPage(.privacy))
        #expect(command("Roze", inSettings: true) == .theme(.pink))
        #expect(command("Weergave", inSettings: true) == .settingsPage(.appearance))
    }

    @Test func aQuestionStillGoesToAyla() {
        let questions = [
            "Welke kleur heeft mijn thema?", "Waarom is mijn kluis groen?", "Ik vind blauw een mooie kleur voor een logo, wat vind jij?",
            "Wat staat er in mijn stages?", "Kun je me helpen met mijn eindstage bij Philips beschrijven?", "Hoe was mijn dag",
            "Maak een cv met een blauwe kop", "Ik ga naar mijn stages kijken morgen", "Ik heb een grote tekst geschreven over mijn stage bij Philips en wil die korter",
            "Mijn privacy is belangrijk voor mij", "Zet mijn stage in de kluis", "Ja", "Nee", "Graag", "Klaar", "Ik ben terug",
            "Maak een lijst van wat er in mijn kluis mist", "Welke apparaten zijn ingelogd?",
            "Bewaar deze stage in mijn kluis", "Hoe bewaar ik een vacature?", "Zoek vacatures als frontend developer",
        ]
        for text in questions {
            #expect(command(text) == nil, "\(text)")
        }
    }
}
