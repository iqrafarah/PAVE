import Foundation
import Testing
@testable import PAVECore

struct AylaVaultOfferTests {
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

    @Test func aQuestionAboutWhatIsInTheVaultGetsJaAndNee() {
        let answer = reply("Ik zie je LiveWall-stage niet in de items die ik mag gebruiken.")
        #expect(AylaVaultOffer.question(for: answer, asked: "Heb ik in de kluis al iets over mijn stage?") == AylaVaultOffer.question)
        #expect(AylaVaultOffer.offersToAddEvidence(answer, asked: "Heb ik in de kluis al iets over mijn stage?"))
        #expect(AylaVaultOffer.question(for: reply("Ik zie niets in je kluis over Scrum."), asked: "Wat weet je over Scrum?") == AylaVaultOffer.question)
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
        #expect(AylaVaultOffer.question(for: reply("Zal ik het toevoegen?", navigation: .addEvidence), asked: "") == AylaVaultOffer.question)
        #expect(AylaVaultOffer.offersToAddEvidence(reply("Ik zet je stage klaar.", action: .addVaultItem), asked: ""))
    }

    @Test func whatCountsAsYesAndWhichSkillsShePicked() {
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
