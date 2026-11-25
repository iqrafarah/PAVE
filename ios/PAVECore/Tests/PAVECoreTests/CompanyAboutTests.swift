import Foundation
import Testing
@testable import PAVECore

struct CompanyAboutTests {
    @Test func theAnswerKeepsOnlySafeSources() throws {
        let json = """
        {"about":{"about":"Kade adviseert over cloud.","sector":"IT-advies","locations":["Eindhoven"],"website":"kade.nl",
        "facts":[{"label":"Traineeship","text":"Starters volgen een traineeship."}],
        "sources":[{"title":"Over Kade","url":"https://kade.nl/over"},{"title":"Oud","url":"http://kade.nl"}]},
        "foundAt":"2026-11-25T10:00:00Z"}
        """
        let about = try #require(SupabaseAylaService.companyAbout(from: Data(json.utf8)))
        #expect(about.sources.map(\.url.absoluteString) == ["https://kade.nl/over"])
        #expect(about.websiteURL?.absoluteString == "https://kade.nl")
        #expect(about.facts.first?.label == "Traineeship")
    }

    @Test func nothingFoundOrNoSourceShowsNothing() {
        #expect(SupabaseAylaService.companyAbout(from: Data("{}".utf8)) == nil)
        let noSource = #"{"about":{"about":"Een bedrijf.","sources":[]}}"#
        #expect(SupabaseAylaService.companyAbout(from: Data(noSource.utf8)) == nil)
    }

    @Test func aLookupIsKeptForAMonth() throws {
        let store = CompanyAboutStore(folder: URL.temporaryDirectory.appending(path: "about-\(UUID().uuidString)"))
        let found = CompanyAbout(about: "Kade adviseert.", sources: [.init(title: "Kade", url: URL(string: "https://kade.nl")!)], foundAt: .now)
        store.save(found, company: "Kade Consultancy", city: "Eindhoven")
        #expect(store.load(company: "kade consultancy", city: "Eindhoven")?.about == "Kade adviseert.")
        #expect(store.load(company: "Kade Consultancy", city: "Eindhoven", now: .now.addingTimeInterval(31 * 86_400)) == nil)
        #expect(store.load(company: "Kade Consultancy", city: nil) == nil)
    }
}
