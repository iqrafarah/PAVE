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
        #expect(request.missingFields == [.organisation, .contact])
    }

    @Test func onlyTheOrganisationAndOnePersonAreNeeded() throws {
        var request = VaultConfirmationRequest(item: VaultItem(id: "s", category: .internships, title: "Eindstage"))
        request.choose(try Self.organization("o1", "Coolblue", kind: "company"))
        #expect(request.missingFields == [.contact])
        // Filters only narrow the list: without a person the request is still incomplete.
        request.filters.function = "Stagebegeleider"
        #expect(request.missingFields == [.contact])
        request.contact = Self.person("c1", "Jan", function: "Stagebegeleider")
        #expect(request.missingFields.isEmpty)
    }

    @Test func anotherOrganisationClearsThePersonAndTheFilters() throws {
        var request = VaultConfirmationRequest(item: VaultItem(id: "s", category: .internships, title: "Eindstage"))
        request.choose(try Self.organization("o1", "Coolblue", kind: "company"), source: .evidence)
        request.contact = Self.person("c1", "Jan")
        request.filters.locationID = "l1"
        request.search = "jan"
        request.choose(try Self.organization("o2", "Fontys", kind: "school"))
        #expect(request.contact == nil)
        #expect(request.filters.isEmpty)
        #expect(request.search.isEmpty)
        #expect(request.organizationSource == .chosen)
    }

    @Test func theOrganisationIsKnownByIDFirstFromTheEvidenceThenFromAnEarlierRequest() {
        var item = VaultItem(id: "s", category: .internships, title: "Eindstage", organisationName: "Coolblue")
        #expect(VaultConfirmationRequest.knownOrganizationIDs(for: item).isEmpty)
        item.lastRequest = .init(status: .rejected, organisationName: "Coolblue", requestedAt: .now, organizationID: "o2")
        #expect(VaultConfirmationRequest.knownOrganizationIDs(for: item).map(\.id) == ["o2"])
        item.organizationID = "o1"
        let known = VaultConfirmationRequest.knownOrganizationIDs(for: item)
        #expect(known.map(\.id) == ["o1", "o2"])
        #expect(known.map(\.source) == [.evidence, .earlierRequest])
    }

    @Test func aTypedNameIsOnlyASuggestionWhenItIsUnique() throws {
        let organizations = [
            try Self.organization("o1", "Fontys Hogescholen", kind: "school"),
            try Self.organization("o2", "Albert Heijn", kind: "company"),
            try Self.organization("o3", "Albert  heijn", kind: "company"),
        ]
        let fontys = VaultItem(id: "d", category: .diplomas, title: "Propedeuse", organisationName: " fontys hogescholen ")
        #expect(VaultConfirmationRequest.suggestion(for: fontys, among: organizations)?.id == "o1")
        let ah = VaultItem(id: "w", category: .workExperience, title: "Vakkenvuller", organisationName: "Albert Heijn")
        #expect(VaultConfirmationRequest.suggestion(for: ah, among: organizations) == nil)
        // A suggestion is not a choice: the request stays without organisation.
        #expect(VaultConfirmationRequest(item: fontys).organization == nil)
    }

    @Test func everyKindOfOrganisationHasAFilter() throws {
        #expect(VaultOrganizationKind.allCases.map(\.filterTitle) == ["Onderwijs", "Bedrijven", "Overheid", "Overig"])
        #expect(try Self.organization("g", "Gemeente Breda", kind: "government").kindTitle == "Overheid")
        #expect(try Self.organization("x", "Iets nieuws", kind: "unknown").organizationKind == .other)
    }

    @Test func anOrganisationShowsWhereSomeoneCanConfirm() throws {
        let organization = try Self.decode(
            VaultValidationOrganization.self,
            #"{"id":"o1","name":"Fontys","kind":"school","cities":["Eindhoven","Tilburg","Venlo","Sittard"],"available_contacts":12,"total_count":40}"#
        )
        #expect(organization.citySummary == "Eindhoven, Tilburg +2")
        #expect(organization.availableContacts == 12)
        // The old pick-list has no cities.
        #expect(try Self.organization("o2", "Coolblue", kind: "company").citySummary == nil)
    }

    @Test func aPersonComesWithFunctionDepartmentAndLocation() throws {
        let person = try Self.decode(
            VaultValidationPerson.self,
            #"{"id":"c1","name":"Jan","job_title":null,"function":"Overig","department_id":"d1","department_name":"Stage","location_id":"l1","city":"Breda","organization_id":"o1","total_count":3}"#
        )
        #expect(person.departmentId == "d1")
        #expect(person.locationId == "l1")
        #expect(person.details == "Overig · Stage · Breda")
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

    private static func organization(_ id: String, _ name: String, kind: String) throws -> VaultValidationOrganization {
        try decode(VaultValidationOrganization.self, #"{"id":"\#(id)","name":"\#(name)","kind":"\#(kind)"}"#)
    }

    private static func person(
        _ id: String, _ name: String, function: String = "Docent", department: String = "Stage", city: String = "Breda"
    ) -> VaultValidationPerson {
        VaultValidationPerson(
            id: id, name: name, jobTitle: function, departmentId: "d-\(department)", departmentName: department,
            locationId: "l-\(city)", city: city, organizationId: "o1"
        )
    }

    /// The directory rows come from Supabase in snake_case, exactly as `SupabaseVaultService` decodes them.
    private static func decode<Row: Decodable>(_ type: Row.Type, _ json: String) throws -> Row {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Row.self, from: Data(json.utf8))
    }
}
