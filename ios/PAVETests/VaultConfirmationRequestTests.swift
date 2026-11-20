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
        #expect(request.missingFields == [.organisation, .location, .department, .contact])
    }

    @Test func itNeedsAnOrganisationLocationDepartmentAndOnePerson() throws {
        var request = VaultConfirmationRequest(item: VaultItem(id: "s", category: .internships, title: "Eindstage"))
        request.organization = try Self.decode(VaultValidationOrganization.self, #"{"id":"o1","name":"Coolblue","kind":"company"}"#)
        #expect(request.missingFields == [.location, .department, .contact])
        request.location = try Self.decode(VaultValidationLocation.self, #"{"id":"l1","organization_id":"o1","city":"Breda"}"#)
        #expect(request.missingFields == [.department, .contact])
        request.department = try Self.decode(VaultValidationDepartment.self, #"{"id":"d1","location_id":"l1","name":"Stage"}"#)
        #expect(request.missingFields == [.contact])
        // The function only filters the list: without a person the request is still incomplete.
        request.contactType = "Stagebegeleider"
        #expect(request.missingFields == [.contact])
        request.contact = try Self.decode(
            VaultValidationContact.self,
            #"{"id":"c1","department_id":"d1","name":"Jan","job_title":"Stagebegeleider","is_active":true}"#
        )
        #expect(request.missingFields.isEmpty)
    }

    @Test func aPersonWithoutAFunctionIsOverig() throws {
        let withFunction = try Self.decode(
            VaultValidationContact.self,
            #"{"id":"c1","department_id":"d1","name":"Sanne de Vries","job_title":" Docent ","is_active":true}"#
        )
        let without = try Self.decode(
            VaultValidationContact.self,
            #"{"id":"c2","department_id":"d1","name":"Daan Jansen","job_title":null,"is_active":true}"#
        )
        #expect(VaultConfirmationRequest.function(of: withFunction) == "Docent")
        #expect(VaultConfirmationRequest.function(of: without) == "Overig")
    }

    /// The directory rows come from Supabase in snake_case, exactly as `SupabaseVaultService` decodes them.
    private static func decode<Row: Decodable>(_ type: Row.Type, _ json: String) throws -> Row {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Row.self, from: Data(json.utf8))
    }
}
