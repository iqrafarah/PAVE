import Foundation
import PAVECore

/// A verification request binds the evidence to trusted directory IDs, never learner-entered names.
/// The learner chooses an organisation together with one of its locations ("Albert Heijn · Breda"), then one person
/// there; the department follows from the person.
struct VaultConfirmationRequest: Equatable {
    enum Recipient: CaseIterable, Identifiable {
        case school
        case employer
        case mentor

        var id: Self { self }

        static func suggested(for category: VaultCategory) -> Recipient {
            switch category {
            case .diplomas, .certificates, .badges: .school
            case .workExperience, .internships: .employer
            case .projects, .skills, .feedback, .reflections, .other: .mentor
            }
        }
    }

    enum Field: Equatable {
        case organisation
        case contact
    }

    /// How the location got there: by ID, or picked by the learner. A typed name is never more than a suggestion.
    enum PlaceSource: Equatable {
        case evidence
        case earlierRequest
        case chosen
    }

    var recipient: Recipient
    /// The kind of evidence: who may confirm it depends on it.
    let category: VaultCategory
    var place: VaultValidationPlace?
    var placeSource: PlaceSource?
    var contact: VaultValidationPerson?
    /// Optional; they only narrow the search and are never sent. The location is not one of them: it is chosen.
    var filters = VaultValidationFilters()
    var search = ""
    var message = ""

    init(item: VaultItem) {
        recipient = .suggested(for: item.category)
        category = item.category
    }

    var missingFields: [Field] {
        var fields = [Field]()
        if place == nil { fields.append(.organisation) }
        if contact == nil { fields.append(.contact) }
        return fields
    }

    /// Another location: the person and the filters belong to the old one, so they go. The evidence stays as it is.
    mutating func choose(_ place: VaultValidationPlace, source: PlaceSource = .chosen) {
        guard place.locationId != self.place?.locationId else { return }
        self.place = place
        placeSource = source
        contact = nil
        filters = VaultValidationFilters()
        search = ""
    }

    /// The location of the latest request for this evidence, by ID.
    static func knownLocationID(for item: VaultItem) -> String? { item.lastRequest?.locationID }

    /// The organisations the evidence is known to belong to, by ID, when the location is not known: the one that
    /// issued it, then the one of the latest request.
    static func knownOrganizationIDs(for item: VaultItem) -> [(id: String, source: PlaceSource)] {
        var known = [(id: String, source: PlaceSource)]()
        if let id = item.organizationID { known.append((id, .evidence)) }
        if let id = item.lastRequest?.organizationID, id != item.organizationID { known.append((id, .earlierRequest)) }
        return known
    }

    /// A suggestion from what the learner typed: the one location of the organisation with that name, or the one in
    /// the city they typed or described. Nothing when it is not certain.
    static func suggestion(for item: VaultItem, among places: [VaultValidationPlace]) -> VaultValidationPlace? {
        guard let name = normalised(item.organisationName) else { return nil }
        let named = places.filter { normalised($0.organizationName) == name }
        guard Set(named.map(\.organizationId)).count == 1 else { return nil }
        return onlyPlace(named, typedCity: item.organisationLocation, described: item.description)
    }

    /// The location among these in the city the learner typed; when they typed none, the one their description names,
    /// or else the only one where someone may confirm it. A typed city where it has no location chooses nothing: then
    /// the learner chooses, rather than getting another city.
    static func onlyPlace(_ places: [VaultValidationPlace], typedCity: String?, described: String? = nil) -> VaultValidationPlace? {
        if let found = inCity(places, typed: typedCity) { return found }
        guard normalised(typedCity) == nil else { return nil }
        if let found = inCity(places, typed: described) { return found }
        return places.count == 1 ? places[0] : nil
    }

    /// The one location the text names: "Tilburg", "Tilburg, Nederland" and "Stage bij Fontys in Tilburg." find
    /// Tilburg. With two locations in Tilburg only their name or street settles it ("Westermarkt, Tilburg").
    static func inCity(_ places: [VaultValidationPlace], typed: String?) -> VaultValidationPlace? {
        let found = located(places, in: typed)
        return found.count == 1 ? found[0] : nil
    }

    /// The locations the text names, as whole words: by city, narrowed by the location's name or street when it names
    /// one. A location name alone ("Tilburg-Noord", "Westermarkt") counts too when the text names no city of these.
    static func located(_ places: [VaultValidationPlace], in typed: String?) -> [VaultValidationPlace] {
        guard let typed = normalised(typed) else { return [] }
        let text = " " + words(typed) + " "
        func names(_ value: String?) -> Bool {
            guard let value = normalised(value).map(words), !value.isEmpty else { return false }
            return text.contains(" " + value + " ")
        }
        let inCity = places.filter { names($0.city) }
        let byName = (inCity.isEmpty ? places : inCity).filter { names($0.locationName) || names(street(of: $0.address)) }
        return byName.isEmpty ? inCity : byName
    }

    /// "Heuvelstraat 12, 5038 AA Tilburg" to "Heuvelstraat".
    private static func street(of address: String?) -> String? {
        address?.split(separator: ",").first.map(String.init)
    }

    /// What the organisation search starts with when the city the learner typed or described has several locations of
    /// the organisation: "McDonald's Tilburg", so the learner sees exactly those and picks one.
    static func searchHint(_ places: [VaultValidationPlace], for item: VaultItem) -> String? {
        let text = normalised(item.organisationLocation) != nil ? item.organisationLocation : item.description
        let found = located(places, in: text)
        guard found.count > 1, Set(found.map(\.organizationId)).count == 1, Set(found.map(\.city)).count == 1 else { return nil }
        return "\(found[0].organizationName) \(found[0].city)"
    }

    private static func words(_ text: String) -> String {
        text.split(whereSeparator: { !$0.isLetter && $0 != "-" }).joined(separator: " ")
    }

    /// Whether this location (of an earlier request) is certainly still the right one: it lies in the city the learner
    /// typed, or, when they typed none, the description names its city or no description at all.
    static func fitsTypedCity(_ place: VaultValidationPlace, of item: VaultItem) -> Bool {
        if normalised(item.organisationLocation) != nil { return inCity([place], typed: item.organisationLocation) != nil }
        guard normalised(item.description) != nil else { return true }
        return inCity([place], typed: item.description) != nil
    }

    static func normalised(_ text: String?) -> String? {
        let value = text?
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "nl_NL"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return value?.isEmpty == false ? value : nil
    }

    /// "Docent", or "Overig" for a person without a function.
    static func function(of contact: VaultValidationContact) -> String {
        let value = contact.jobTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false ? value : nil) ?? "Overig"
    }
}

extension VaultModel {
    /// Sends the request by the IDs of the chosen location and person; the server checks again that this person
    /// works there and may confirm it.
    func requestValidation(for item: VaultItem, _ request: VaultConfirmationRequest) async -> String? {
        guard let place = request.place, let contact = request.contact else {
            return VaultMessages.requestMissing(request.missingFields.first ?? .contact)
        }
        return await requestValidation(
            for: item,
            organizationID: place.organizationId,
            locationID: contact.locationId,
            departmentID: contact.departmentId,
            contactID: contact.id,
            message: request.message
        )
    }
}
