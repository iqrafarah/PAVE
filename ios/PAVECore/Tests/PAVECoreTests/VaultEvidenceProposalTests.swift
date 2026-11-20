import Foundation
import Testing
@testable import PAVECore

struct VaultEvidenceProposalTests {
    @Test func theChatCompletesWhatTheDocumentsSay() {
        let documents = VaultEvidenceProposal(
            category: .certificates, title: "Professional Scrum Master I", organisationName: "Scrum.org", issuedOn: VaultDay(year: 2025, month: 6, day: 12),
            description: "Certificaat voor Scrum.", skills: [VaultSkillSuggestion(name: "Scrum", reason: "Op het certificaat")], folder: "Certificaten", logoDocument: 0
        )
        let chat = AylaReply.VaultItemProposal(category: .certificates, title: "PSM I", startDate: "2025-01-01", endDate: "2025-06-01", description: "Je deed examen.", skills: ["scrum", "Agile werken"])
        let merged = documents.merged(with: chat)
        #expect(merged.title == "PSM I")
        #expect(merged.organisationName == "Scrum.org")
        #expect(merged.startDate == VaultDay(year: 2025, month: 1, day: 1) && merged.issuedOn == nil)
        #expect(merged.description == "Certificaat voor Scrum.")
        #expect(merged.skills.map(\.name) == ["Scrum", "Agile werken"])
        #expect(merged.folder == "Certificaten" && merged.logoDocument == 0)
    }

    @Test func aProposalIsReadFromTheFunction() throws {
        let json = Data(#"""
        {"items":[{"category":"certificates","title":"Microsoft Azure Fundamentals (AZ-900)","organisationName":"Microsoft",
        "issuedOn":"2025-03-21","isCurrent":false,"description":"Je haalde het Azure-examen.",
        "skills":[{"name":"Cloud","reason":"Het examen gaat over cloud"}],"folder":"Certificaten","documents":[0,2],
        "website":"microsoft.com","sources":{"period":"pagina 1"},
        "logo":{"data":"QUJD","mimeType":"image/png","source":"microsoft.com"}},
        {"category":"unknown","title":"Cijferlijst","isCurrent":false,"skills":[],"documents":[1],"sources":{}}]}
        """#.utf8)
        struct Response: Decodable { let items: [VaultEvidenceProposal] }
        let items = try JSONDecoder().decode(Response.self, from: json).items
        #expect(items.count == 2)
        #expect(items[0].issuedOn == VaultDay(year: 2025, month: 3, day: 21))
        #expect(items[0].logo?.source == "microsoft.com")
        #expect(items[0].source(of: .period) == "pagina 1")
        #expect(items[1].category == .other)
    }

    @Test func applyingFillsTheDraftAndKeepsTheFolders() {
        var draft = VaultItemDraft(category: .projects, folderIDs: ["folder-1"])
        draft.title = "IMG_2041"
        let certificate = VaultEvidenceProposal(category: .certificates, title: "Azure Fundamentals", organisationName: "Microsoft", issuedOn: VaultDay(year: 2025, month: 3, day: 21))
        let filled = certificate.applied(to: draft)
        #expect(filled.category == .certificates)
        #expect(filled.title == "Azure Fundamentals")
        #expect(filled.filledByAyla && !draft.filledByAyla)
        #expect(filled.folderIDs == ["folder-1"])
        #expect(!filled.isPeriod)
        #expect(filled.issuedOn == VaultDay(year: 2025, month: 3, day: 21))
        #expect(filled.description.isEmpty)
        #expect(certificate.filledFields == [.title, .organisation, .period])

        let internship = VaultEvidenceProposal(category: .internships, title: "Afstudeerstage", startDate: VaultDay(year: 2026, month: 9, day: 1), endDate: VaultDay(year: 2027, month: 1, day: 31), isCurrent: true)
        let running = internship.applied(to: draft)
        #expect(running.isPeriod)
        #expect(running.isCurrent)
        #expect(running.endDate == nil)
    }
}
