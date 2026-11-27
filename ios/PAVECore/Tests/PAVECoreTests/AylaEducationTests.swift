import Foundation
import Testing
@testable import PAVECore

struct AylaEducationTests {
    @Test func studiesComeInAsABlockAndBecomeAStepWithTheirPage() throws {
        let json = """
        {"type":"educations","items":[{"id":"edu_1","name":"Pilotenopleiding","school":"Vliegschool","level":"hbo","city":"Groningen","duration":"4 jaar","url":"https://example.nl/piloot","summary":"Vliegen."},{"id":"edu_2","name":"Cursus","school":"School","level":"master","url":"https://example.nl/c"}],"search":{"what":"piloot","where":""}}
        """
        let block = try JSONDecoder().decode(AylaBlock.self, from: Data(json.utf8))
        guard case .educations(let items, let search) = block else { Issue.record("not educations"); return }
        #expect(items.count == 2)
        #expect(items[1].level == nil)
        #expect(search == EducationSearch(what: "piloot", where: ""))
        #expect(items[0].details == ["HBO", "Groningen", "4 jaar"])
        let step = items[0].planStep
        #expect(step.title == "Pilotenopleiding bij Vliegschool bekijken")
        #expect(step.kind == .research)
        #expect(step.metadata[AylaEducation.urlKey] == "https://example.nl/piloot")
        let again = try JSONDecoder().decode(AylaBlock.self, from: JSONEncoder().encode(block))
        #expect(again == block)
    }
}
