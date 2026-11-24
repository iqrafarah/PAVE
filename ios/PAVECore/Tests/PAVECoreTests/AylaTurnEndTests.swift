import Testing
@testable import PAVECore

struct AylaTurnEndTests {
    @Test func waitsLongerWhenTheSentenceCannotBeOver() {
        #expect(AylaTurnEnd.pause(after: "Ik zoek een baan als eh") == AylaTurnEnd.unfinished)
        #expect(AylaTurnEnd.pause(after: "Vergelijk die van Appwerk met") == AylaTurnEnd.unfinished)
        #expect(AylaTurnEnd.pause(after: "Wat mis ik nog voor de") == AylaTurnEnd.unfinished)
        #expect(AylaTurnEnd.pause(after: "Ik heb Swift gedaan,") == AylaTurnEnd.unfinished)
    }

    @Test func answersAtOnceToAQuestionOrAYes() {
        #expect(AylaTurnEnd.pause(after: "Welke vacature past het best bij mij?") == AylaTurnEnd.finished)
        #expect(AylaTurnEnd.pause(after: "Ja") == AylaTurnEnd.finished)
        #expect(AylaTurnEnd.pause(after: "Nee, dankjewel") == AylaTurnEnd.finished)
        #expect(AylaTurnEnd.pause(after: "Bewaar de tweede vacature maar.") == AylaTurnEnd.finished)
    }

    @Test func letsDutchEndOnSmallWords() {
        #expect(AylaTurnEnd.pause(after: "Vergelijk deze met die") == AylaTurnEnd.usual)
        #expect(AylaTurnEnd.pause(after: "Zet het geluid uit") == AylaTurnEnd.usual)
        #expect(AylaTurnEnd.pause(after: "Bewaar hem maar") == AylaTurnEnd.usual)
    }

    @Test func givesAFewWordsTimeToGrow() {
        #expect(AylaTurnEnd.pause(after: "Vacatures") == AylaTurnEnd.short)
        #expect(AylaTurnEnd.pause(after: "Zoek stages") == AylaTurnEnd.short)
    }

    @Test func waitsTheUsualTimeOtherwise() {
        #expect(AylaTurnEnd.pause(after: "Zoek vacatures voor iOS ontwikkelaar in Eindhoven") == AylaTurnEnd.usual)
        #expect(AylaTurnEnd.pause(after: "") == AylaTurnEnd.usual)
    }
}
