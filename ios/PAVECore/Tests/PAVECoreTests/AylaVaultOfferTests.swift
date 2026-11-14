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
