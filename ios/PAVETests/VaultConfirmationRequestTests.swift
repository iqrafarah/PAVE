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

    @Test func onlyTheOrganisationWithItsLocationAndOnePersonAreNeeded() {
        var request = VaultConfirmationRequest(item: VaultItem(id: "s", category: .internships, title: "Eindstage"))
        request.choose(Self.place("l1", "Albert Heijn", city: "Breda"))
        #expect(request.missingFields == [.contact])
        // Filters only narrow the list: without a person the request is still incomplete.
        request.filters.function = "Stagebegeleider"
        #expect(request.missingFields == [.contact])
        request.contact = Self.person("c1", "Jan", function: "Stagebegeleider")
        #expect(request.missingFields.isEmpty)
    }

    @Test func anotherLocationClearsThePersonAndTheFilters() {
        var request = VaultConfirmationRequest(item: VaultItem(id: "s", category: .internships, title: "Eindstage"))
        request.choose(Self.place("l1", "Albert Heijn", city: "Breda"), source: .earlierRequest)
        request.contact = Self.person("c1", "Jan")
        request.filters.department = "Stage"
        request.search = "jan"
        // Same organisation, other location: another entrepreneur, other people.
        request.choose(Self.place("l2", "Albert Heijn", city: "Tilburg"))
        #expect(request.contact == nil)
        #expect(request.filters.isEmpty)
        #expect(request.search.isEmpty)
        #expect(request.placeSource == .chosen)
    }

    @Test func theLocationIsKnownFromAnEarlierRequest() {
        var item = VaultItem(id: "s", category: .internships, title: "Eindstage", organisationName: "Albert Heijn")
        #expect(VaultConfirmationRequest.knownLocationID(for: item) == nil)
        #expect(VaultConfirmationRequest.knownOrganizationIDs(for: item).isEmpty)
        item.lastRequest = .init(status: .rejected, organisationName: "Albert Heijn", requestedAt: .now, organizationID: "o2", locationID: "l2")
        #expect(VaultConfirmationRequest.knownLocationID(for: item) == "l2")
        item.organizationID = "o1"
        let known = VaultConfirmationRequest.knownOrganizationIDs(for: item)
        #expect(known.map(\.id) == ["o1", "o2"])
        #expect(known.map(\.source) == [.evidence, .earlierRequest])
    }

    @Test func aKnownOrganisationGetsItsLocationOnlyWhenItIsCertain() {
        let breda = Self.place("l1", "Albert Heijn", city: "Breda")
        let tilburg = Self.place("l2", "Albert Heijn", city: "Tilburg")
        #expect(VaultConfirmationRequest.onlyPlace([breda], typedCity: nil) == breda)
        #expect(VaultConfirmationRequest.onlyPlace([breda, tilburg], typedCity: nil) == nil)
        #expect(VaultConfirmationRequest.onlyPlace([breda, tilburg], typedCity: " tilburg ") == tilburg)
    }

    @Test func theCityOfTheEvidenceDecidesTheLocation() {
        let tilburg = Self.place("l1", "Fontys", city: "Tilburg")
        let eindhoven = Self.place("l2", "Fontys", city: "Eindhoven")
        #expect(VaultConfirmationRequest.inCity([tilburg, eindhoven], typed: "Tilburg, Nederland") == tilburg)
        #expect(VaultConfirmationRequest.inCity([tilburg, eindhoven], typed: "Utrecht") == nil)
        let item = VaultItem(id: "d", category: .diplomas, title: "Propedeuse", organisationName: "Fontys", organisationLocation: "Tilburg")
        // An earlier request to Eindhoven does not overrule the Tilburg of the evidence.
        #expect(!VaultConfirmationRequest.fitsTypedCity(eindhoven, of: item))
        #expect(VaultConfirmationRequest.fitsTypedCity(tilburg, of: item))
        #expect(VaultConfirmationRequest.fitsTypedCity(eindhoven, of: VaultItem(id: "x", category: .diplomas, title: "X")))
    }

    @Test func theDescriptionNamesTheCityWhenNoneWasTyped() {
        let tilburg = Self.place("l1", "Fontys", city: "Tilburg")
        let eindhoven = Self.place("l2", "Fontys", city: "Eindhoven")
        let bosch = Self.place("l3", "Fontys", city: "Den Bosch")
        let described = "Propedeuse behaald bij Fontys in Tilburg."
        #expect(VaultConfirmationRequest.inCity([tilburg, eindhoven], typed: described) == tilburg)
        #expect(VaultConfirmationRequest.inCity([tilburg, bosch], typed: "Stage in Den Bosch") == bosch)
        #expect(VaultConfirmationRequest.onlyPlace([eindhoven, tilburg], typedCity: nil, described: described) == tilburg)
        // The typed city wins over the description; a typed city without a location chooses nothing.
        #expect(VaultConfirmationRequest.onlyPlace([eindhoven, tilburg], typedCity: "Eindhoven", described: described) == eindhoven)
        #expect(VaultConfirmationRequest.onlyPlace([eindhoven], typedCity: "Tilburg") == nil)
        let item = VaultItem(id: "d", category: .diplomas, title: "Propedeuse", description: described, organisationName: "Fontys")
        // An earlier request to Eindhoven does not overrule the Tilburg of the description.
        #expect(!VaultConfirmationRequest.fitsTypedCity(eindhoven, of: item))
        #expect(VaultConfirmationRequest.fitsTypedCity(tilburg, of: item))
    }

    @Test func twoLocationsInOneCityAreToldApartByNameOrStreet() {
        let centrum = Self.place("l1", "McDonald's", city: "Tilburg", locationName: "Centrum", address: "Heuvelstraat 12, 5038 AA Tilburg")
        let reeshof = Self.place("l2", "McDonald's", city: "Tilburg", locationName: "Reeshof")
        let breda = Self.place("l3", "McDonald's", city: "Breda")
        let places = [centrum, reeshof, breda]
        #expect(centrum.title == "McDonald's · Centrum, Tilburg")
        #expect(breda.title == "McDonald's · Breda")
        #expect(VaultLocationTitle.make(name: "Tilburg-Noord", city: "Tilburg") == "Tilburg-Noord")
        // The city alone is not enough: the learner chooses, never the app.
        #expect(VaultConfirmationRequest.inCity(places, typed: "Tilburg") == nil)
        #expect(VaultConfirmationRequest.onlyPlace(places, typedCity: "Tilburg") == nil)
        // The name or the street settles it, also without the city.
        #expect(VaultConfirmationRequest.inCity(places, typed: "Reeshof, Tilburg") == reeshof)
        #expect(VaultConfirmationRequest.inCity(places, typed: "Bijbaan bij de McDonald's aan de Heuvelstraat") == centrum)
        #expect(VaultConfirmationRequest.inCity(places, typed: "Breda") == breda)
        // The search then starts with just the locations in that city.
        let item = VaultItem(id: "w", category: .workExperience, title: "Crew", organisationName: "McDonald's", organisationLocation: "Tilburg")
        #expect(VaultConfirmationRequest.searchHint(places, for: item) == "McDonald's Tilburg")
        #expect(VaultConfirmationRequest.suggestion(for: item, among: places) == nil)
        let known = VaultItem(id: "w", category: .workExperience, title: "Crew", organisationName: "McDonald's", organisationLocation: "Tilburg Reeshof")
        #expect(VaultConfirmationRequest.suggestion(for: known, among: places) == reeshof)
        #expect(VaultConfirmationRequest.searchHint(places, for: known) == nil)
    }

    @Test func aTypedNameIsOnlyASuggestionWhenItIsCertain() {
        let places = [
            Self.place("l1", "Fontys Hogescholen", organization: "o1", city: "Eindhoven"),
            Self.place("l2", "Albert Heijn", organization: "o2", city: "Breda"),
            Self.place("l3", "Albert Heijn", organization: "o2", city: "Tilburg"),
            Self.place("l4", "Albert  heijn", organization: "o3", city: "Breda"),
        ]
        let fontys = VaultItem(id: "d", category: .diplomas, title: "Propedeuse", organisationName: " fontys hogescholen ")
        #expect(VaultConfirmationRequest.suggestion(for: fontys, among: places)?.locationId == "l1")
        // Two organisations with that name: the learner chooses.
        let ah = VaultItem(id: "w", category: .workExperience, title: "Vakkenvuller", organisationName: "Albert Heijn", organisationLocation: "Tilburg")
        #expect(VaultConfirmationRequest.suggestion(for: ah, among: places) == nil)
        // One organisation, the typed city picks the location.
        #expect(VaultConfirmationRequest.suggestion(for: ah, among: Array(places.prefix(3)))?.locationId == "l3")
        // A suggestion is not a choice: the request stays without organisation.
        #expect(VaultConfirmationRequest(item: fontys).place == nil)
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

    @Test func aPlaceCarriesTheLogoOfItsOrganisationOnlyOverHTTPS() throws {
        let place = try Self.decode(
            VaultValidationPlace.self,
            #"{"organization_id":"o1","organization_name":"Coolblue","kind":"company","logo_url":"https://coolblue.nl/logo.png","location_id":"l1","city":"Breda","available_contacts":2,"total_count":1}"#
        )
        #expect(place.logoURL?.host() == "coolblue.nl")
        #expect(place.title == "Coolblue · Breda")
        let insecure = VaultValidationPlace(organizationId: "o1", organizationName: "X", kind: "other", logoUrl: "http://x.nl/a.png", locationId: "l1", city: "Breda")
        #expect(insecure.logoURL == nil)
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

    private static func place(
        _ location: String, _ name: String, organization: String = "o1", kind: String = "company", city: String,
        locationName: String? = nil, address: String? = nil
    ) -> VaultValidationPlace {
        VaultValidationPlace(
            organizationId: organization, organizationName: name, kind: kind, locationId: location, city: city,
            locationName: locationName, address: address
        )
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
