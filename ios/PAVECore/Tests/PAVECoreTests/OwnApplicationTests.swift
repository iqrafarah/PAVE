import Foundation
import Testing
@testable import PAVECore

@Suite struct OwnApplicationTests {
    @Test func needsACompany() {
        #expect(OwnApplication(company: "   ").problem == .noCompany)
        #expect(OwnApplication(company: "Jumbo").problem == nil)
    }

    @Test func anEmptyJobIsAnOpenApplication() {
        let vacancy = OwnApplication(company: " Jumbo ", city: "").vacancy(id: "own-1")
        #expect(vacancy.title == Vacancy.openApplicationTitle)
        #expect(vacancy.company == "Jumbo")
        #expect(vacancy.city == nil)
        #expect(vacancy.source == .own)
        #expect(vacancy.isOpenApplication)
    }

    @Test func aJobIsNotOpen() {
        let vacancy = OwnApplication(company: "Kees van der Westen Espressonistic Works B.V.", title: "Embedded softwareontwikkelaar").vacancy()
        #expect(!vacancy.isOpenApplication)
        #expect(vacancy.id.hasPrefix("own-"))
    }

    @Test(arguments: ["werkenbij.ah.nl/vacature/123", "https://www.jumbo.com/werken", "HTTP://example.nl"])
    func acceptsLinks(_ link: String) {
        let own = OwnApplication(company: "Jumbo", link: link)
        #expect(own.problem == nil)
        #expect(own.vacancy().url?.scheme?.lowercased().hasPrefix("http") == true)
    }

    @Test(arguments: ["jan@", "geen link", "localhost"])
    func refusesWhatIsNoLink(_ link: String) {
        #expect(OwnApplication(company: "Jumbo", link: link).problem == .badLink)
    }

    @Test func keepsTheTextWithinLimits() {
        let vacancy = OwnApplication(company: "Jumbo", text: String(repeating: "é’ 🙂 ", count: 1000)).vacancy()
        #expect((vacancy.summary?.count ?? 0) <= 2000)
    }

    @Test func theLetterOfAnOpenApplicationNamesNoVacancy() {
        let vacancy = OwnApplication(company: "Jumbo").vacancy()
        let draft = ApplicationBuilder.draft(for: vacancy, items: [], name: "Ravi")
        let opening = draft.letter.paragraphs.first?.text ?? ""
        #expect(!opening.contains("vacature"))
        #expect(opening.contains("Jumbo"))
    }
}
