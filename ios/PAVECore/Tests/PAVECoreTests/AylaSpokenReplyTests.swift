import Testing
@testable import PAVECore

struct AylaSpokenReplyTests {
    private func reply(_ text: String, question: AylaReply.Question? = nil) -> AylaReply {
        AylaReply(id: "r", conversationId: "c", text: text, question: question)
    }

    @Test func yesAndNoAreSaidAsSuch() {
        #expect(AylaSpokenReply.choicesLine(["Ja", "Nee"]) == "Zeg ja of nee.")
        #expect(AylaSpokenReply.choicesLine(["Ja, graag", "Liever niet"], canNod: true) == "Zeg ja of nee, of knik of schud je hoofd.")
    }

    @Test func otherChoicesAreListed() {
        #expect(AylaSpokenReply.choicesLine(["Stage", "Project", "Diploma"]) == "Je kunt kiezen: Stage, Project of Diploma.")
        #expect(AylaSpokenReply.choicesLine(["Alleen"]) == nil)
    }

    @Test func siriReadsAShortPlainAnswer() {
        let answer = AylaSpokenReply.forSiri(reply("Je **volgende stap** is een Scrum-certificaat halen."), choices: [], goOn: "Ga verder in PAVE.")
        #expect(answer == "Je volgende stap is een Scrum-certificaat halen.")
    }

    @Test func aLongAnswerIsCutAndPointsToPave() {
        let long = "Een. Twee. Drie. Vier. Vijf. Zes."
        let answer = AylaSpokenReply.forSiri(reply(long), choices: [], goOn: "Ga verder in PAVE.")
        #expect(answer == "Een. Twee. Drie. Vier. Ga verder in PAVE.")
    }

    @Test func aQuestionGetsItsChoicesAndHowToGoOn() {
        let question = AylaReply.Question(text: "Zal ik het in je kluis zetten?", choices: [.init(id: "y", label: "Ja"), .init(id: "n", label: "Nee")])
        let answer = AylaSpokenReply.forSiri(reply("Ik heb je stage.", question: question), choices: ["Ja", "Nee"], goOn: "Ga verder in PAVE.")
        #expect(answer == "Ik heb je stage. Zal ik het in je kluis zetten? Zeg ja of nee. Ga verder in PAVE.")
    }
}
