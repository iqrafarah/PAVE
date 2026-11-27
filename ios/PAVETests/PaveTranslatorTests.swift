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

    /// Keys with fewer than 3 letters of their own are not found in a filled-in text, so the code formats them.
    @Test func formatsShortTextsWithAValue() {
        #expect(PaveTranslator.translate("Safari op iPhone", into: .english) == "Safari op iPhone")
        #expect(PaveTranslator.format("%@ op %@", ["Safari", "iPhone"], into: .english) == "Safari on iPhone")
        #expect(PaveTranslator.format("%@ op %@", ["Safari", "iPhone"], into: .papiamentu) == "Safari riba iPhone")
        #expect(PaveTranslator.format("%@ op %@", ["Safari", "iPhone"], into: .dutch) == "Safari op iPhone")
        #expect(PaveTranslator.format("Nu: %@", ["Mijn stageplan"], into: .english) == "Now: Mijn stageplan")
        #expect(PaveTranslator.format("Onbekend: %@", ["x"], into: .english) == "Onbekend: x")
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
