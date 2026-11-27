import Foundation

/// The kinds of organisation in the directory, which are also the filters of the organisation search.
public enum VaultOrganizationKind: String, CaseIterable, Identifiable, Sendable {
    case school
    case company
    case government
    case other

    public var id: Self { self }

    /// "Onderwijs": the filter, and the label under a name.
    public var title: String {
        switch self {
        case .school: "Onderwijs"
        case .company: "Bedrijf"
        case .government: "Overheid"
        case .other: "Overig"
        }
    }

    public var filterTitle: String { self == .company ? "Bedrijven" : title }
}

public struct VaultValidationOrganization: Decodable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let kind: String
    /// The cities where someone may confirm the evidence; nil from the old pick-list.
    public let cities: [String]?
    /// How many persons there may confirm this kind of evidence; nil from the old pick-list.
    public let availableContacts: Int?

    public init(id: String, name: String, kind: String, cities: [String]? = nil, availableContacts: Int? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.cities = cities
        self.availableContacts = availableContacts
    }

    public var organizationKind: VaultOrganizationKind { VaultOrganizationKind(rawValue: kind) ?? .other }
    public var kindTitle: String { organizationKind.title }

    /// "Eindhoven, Tilburg +3".
    public var citySummary: String? {
        guard let cities, !cities.isEmpty else { return nil }
        let shown = cities.prefix(2).joined(separator: ", ")
        return cities.count > 2 ? "\(shown) +\(cities.count - 2)" : shown
    }
}

/// One location of an organisation, chosen in one go: "Albert Heijn · Breda". A location can be run by other people
/// than the rest of the organisation, so the request goes to someone there.
public struct VaultValidationPlace: Decodable, Hashable, Identifiable, Sendable {
    public let organizationId: String
    public let organizationName: String
    public let kind: String
    /// `organizations.logo_url`: an https address, set by the organisation or the team.
    public let logoUrl: String?
    public let locationId: String
    public let city: String
    /// The name of the location within its city ("Westermarkt"), when the organisation has more than one there.
    public let locationName: String?
    /// The street address, so the learner knows which location it is.
    public let address: String?
    /// How many persons here may confirm this kind of evidence; nil when not known.
    public let availableContacts: Int?

    public init(
        organizationId: String, organizationName: String, kind: String, logoUrl: String? = nil,
        locationId: String, city: String, locationName: String? = nil, address: String? = nil,
        availableContacts: Int? = nil
    ) {
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.kind = kind
        self.logoUrl = logoUrl
        self.locationId = locationId
        self.city = city
        self.locationName = locationName
        self.address = address
        self.availableContacts = availableContacts
    }

    /// The logo, only an https address.
    public var logoURL: URL? {
        guard let logoUrl, let url = URL(string: logoUrl), url.scheme == "https" else { return nil }
        return url
    }

    public var id: String { locationId }
    public var organizationKind: VaultOrganizationKind { VaultOrganizationKind(rawValue: kind) ?? .other }
    /// "Breda", or "Westermarkt, Tilburg" when it has a name.
    public var locationTitle: String { VaultLocationTitle.make(name: locationName, city: city) }
    /// "Albert Heijn · Breda", "McDonald's · Westermarkt, Tilburg".
    public var title: String { "\(organizationName) · \(locationTitle)" }
    /// The address, when there is one.
    public var addressLine: String? {
        let value = address?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}

/// How a location is named to the learner.
public enum VaultLocationTitle {
    /// "Tilburg" without a name; "Westermarkt, Tilburg" with one; "Tilburg-Noord" when the name already says the city.
    public static func make(name: String?, city: String) -> String {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return city }
        if name.range(of: city, options: [.caseInsensitive, .diacriticInsensitive]) != nil { return name }
        return "\(name), \(city)"
    }
}

/// A page of search results, with the number of results over all pages.
public struct VaultValidationPage<Row: Sendable>: Sendable {
    public static var size: Int { 25 }
    public let rows: [Row]
    public let total: Int

    public init(rows: [Row], total: Int) {
        self.rows = rows
        self.total = total
    }
}

/// Optional filters on the persons of one organisation.
public struct VaultValidationFilters: Equatable, Hashable, Sendable {
    public var locationID: String?
    /// By name: "ICT" is one choice, also when several locations have an ICT.
    public var department: String?
    public var function: String?

    public init(locationID: String? = nil, department: String? = nil, function: String? = nil) {
        self.locationID = locationID
        self.department = department
        self.function = function
    }

    public var isEmpty: Bool { locationID == nil && department == nil && function == nil }
}

/// One choice of a filter: a location, a department (of one location) or a function, with how many persons it has.
public struct VaultValidationFilterOption: Decodable, Hashable, Identifiable, Sendable {
    public enum Filter: String, Decodable, Sendable {
        case location
        case department
        case function
    }

    public let filter: Filter
    public let value: String
    public let label: String
    public let locationId: String?
    public let people: Int

    public var id: String { "\(filter.rawValue):\(value)" }

    public init(filter: Filter, value: String, label: String, locationId: String? = nil, people: Int) {
        self.filter = filter
        self.value = value
        self.label = label
        self.locationId = locationId
        self.people = people
    }
}

public struct VaultValidationLocation: Decodable, Hashable, Identifiable, Sendable {
    public let id: String
    public let organizationId: String
    public let city: String
}

public struct VaultValidationDepartment: Decodable, Hashable, Identifiable, Sendable {
    public let id: String
    public let locationId: String
    public let name: String
}

public struct VaultValidationContact: Decodable, Hashable, Identifiable, Sendable {
    public let id: String
    public let departmentId: String
    public let name: String
    public let jobTitle: String?
    public let isActive: Bool
}

/// One person who may confirm evidence, with where they work: enough to tell two people with the same name apart
/// and to send the request without asking the learner for location and department first.
public struct VaultValidationPerson: Decodable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let jobTitle: String?
    public let departmentId: String
    public let departmentName: String
    public let locationId: String
    public let city: String
    public let organizationId: String
    /// Only for earlier contacts, which can be of any organisation.
    public let organizationName: String?
    /// The name of their location within its city, when it has one.
    public let locationName: String?

    public init(
        id: String, name: String, jobTitle: String?, departmentId: String, departmentName: String,
        locationId: String, city: String, organizationId: String, organizationName: String? = nil,
        locationName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.jobTitle = jobTitle
        self.departmentId = departmentId
        self.departmentName = departmentName
        self.locationId = locationId
        self.city = city
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.locationName = locationName
    }

    /// "Docent", or "Overig" for a person without a function.
    public var function: String {
        let value = jobTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false ? value : nil) ?? "Overig"
    }

    /// "Breda", or "Westermarkt, Tilburg".
    public var locationTitle: String { VaultLocationTitle.make(name: locationName, city: city) }

    /// "Docent · HBO-ICT · Eindhoven": shown with every person.
    public var details: String { [function, departmentName, locationTitle].joined(separator: " · ") }
}
