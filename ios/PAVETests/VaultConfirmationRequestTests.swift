import PAVECore
import Testing
@testable import PAVE

@MainActor
struct VaultConfirmationRequestTests {
    @Test func theKindOfEvidenceSuggestsWhoConfirmsIt() {
        #expect(VaultConfirmationRequest(item: VaultItem(id: "d", category: .diplomas, title: "Hbo-ICT")).recipient == .school)
        #expect(VaultConfirmationRequest(item: VaultItem(id: "s", category: .internships, title: "Eindstage")).recipient == .employer)
        #expect(VaultConfirmationRequest(item: VaultItem(id: "p", category: .projects, title: "App")).recipient == .mentor)
    }

    @Test func itNeedsAnOrganisationAndAnEmailAddress() {
        var request = VaultConfirmationRequest(item: VaultItem(id: "s", category: .internships, title: "Eindstage"))
        #expect(request.missingFields == [.organisation, .email])
        request.organisation = "LiveWall"
        request.email = "jan@livewall"
        #expect(request.missingFields == [.email])
        request.email = " jan@livewall.nl "
        #expect(request.missingFields.isEmpty)
    }

    @Test func roughEmailCheck() {
        #expect(VaultConfirmationRequest.looksLikeEmail("a.b@fontys.nl"))
        #expect(!VaultConfirmationRequest.looksLikeEmail("fontys.nl"))
        #expect(!VaultConfirmationRequest.looksLikeEmail("a@b@c.nl"))
        #expect(!VaultConfirmationRequest.looksLikeEmail("a b@c.nl"))
    }
}
