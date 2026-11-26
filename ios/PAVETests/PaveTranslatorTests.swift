import PAVECore
import Testing
@testable import PAVE

struct PaveTranslatorTests {
    @Test func translatesExactTexts() {
        #expect(PaveTranslator.translate("Instellingen", into: .english) == "Settings")
        #expect(PaveTranslator.translate("Instellingen", into: .papiamentu) == "Konfigurashon")
        #expect(PaveTranslator.translate("Instellingen", into: .dutch) == "Instellingen")
    }

    @Test func translatesTextsWithAValue() {
        #expect(PaveTranslator.translate("Na 15 minuten", into: .english) == "After 15 minutes")
        #expect(PaveTranslator.translate("Stap 2 van 5: Bewijs in je kluis", into: .english) == "Step 2 of 5: Evidence in your vault")
    }

    @Test func leavesUnknownTextsAlone() {
        #expect(PaveTranslator.translate("Mijn stage bij LiveWall was leuk", into: .english) == "Mijn stage bij LiveWall was leuk")
    }

    @Test func fillsValuesInOrderOrByNumber() {
        #expect(TranslationTable.fill("%@ at %@", with: ["Cv", "Kade"]) == "Cv at Kade")
        #expect(TranslationTable.fill("%2$@, %1$@", with: ["a", "b"]) == "b, a")
        #expect(TranslationTable.fill("100% match", with: []) == "100% match")
    }
}
