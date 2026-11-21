import Foundation

public struct VaultValidationOrganization: Decodable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let kind: String

    public var kindTitle: String { kind == "school" ? "School of opleiding" : "Bedrijf" }
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
