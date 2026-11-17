import Foundation
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

    @Test func itStartsWithNothingChosen() {
        let request = VaultConfirmationRequest(item: VaultItem(id: "s", category: .internships, title: "Eindstage"))
        #expect(request.missingFields == [.organisation, .location, .contactType, .contact])
    }

    @Test func itNeedsAnOrganisationLocationContactTypeAndContact() throws {
        var request = VaultConfirmationRequest(item: VaultItem(id: "s", category: .internships, title: "Eindstage"))
        request.organization = try Self.decode(VaultValidationOrganization.self, #"{"id":"o1","name":"LiveWall","kind":"company"}"#)
        #expect(request.missingFields == [.location, .contactType, .contact])
        request.location = try Self.decode(VaultValidationLocation.self, #"{"id":"l1","organization_id":"o1","city":"Eindhoven"}"#)
        #expect(request.missingFields == [.contactType, .contact])
        request.contactType = "Stagebegeleider"
        #expect(request.missingFields == [.contact])
        request.contact = try Self.decode(
            VaultValidationContact.self,
            #"{"id":"c1","organization_id":"o1","location_id":"l1","department_id":null,"name":"Jan","job_title":"Stagebegeleider","is_active":true}"#
        )
        #expect(request.missingFields.isEmpty)
    }

    @Test func aDepartmentIsOptional() throws {
        var request = VaultConfirmationRequest(item: VaultItem(id: "d", category: .diplomas, title: "Hbo-ICT"))
        request.organization = try Self.decode(VaultValidationOrganization.self, #"{"id":"o1","name":"Fontys","kind":"school"}"#)
        request.location = try Self.decode(VaultValidationLocation.self, #"{"id":"l1","organization_id":"o1","city":"Eindhoven"}"#)
        request.contactType = "Docent"
        request.contact = try Self.decode(
            VaultValidationContact.self,
            #"{"id":"c1","organization_id":"o1","location_id":null,"department_id":null,"name":"Sanne","job_title":"Docent","is_active":true}"#
        )
        #expect(request.department == nil)
        #expect(request.missingFields.isEmpty)
    }

    /// The directory rows come from Supabase in snake_case, exactly as `SupabaseVaultService` decodes them.
    private static func decode<Row: Decodable>(_ type: Row.Type, _ json: String) throws -> Row {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Row.self, from: Data(json.utf8))
    }
}
