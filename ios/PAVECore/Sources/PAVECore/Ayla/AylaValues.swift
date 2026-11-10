import Foundation

/// String values from the Ayla contract. They are open sets, so a value the
/// server adds later does not stop an older app from reading the reply.
public protocol AylaValue: RawRepresentable, Codable, Hashable, Sendable where RawValue == String {
    init(rawValue: String)
}

/// A vault category as Ayla names it; an open set, see `VaultCategory` for the ones the app knows.
public struct AylaVaultCategory: AylaValue {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let diplomas = Self(rawValue: "diplomas")
    public static let certificates = Self(rawValue: "certificates")
    public static let badges = Self(rawValue: "badges")
    public static let projects = Self(rawValue: "projects")
    public static let workExperience = Self(rawValue: "workExperience")
    public static let internships = Self(rawValue: "internships")
    public static let skills = Self(rawValue: "skills")
    public static let feedback = Self(rawValue: "feedback")
    public static let reflections = Self(rawValue: "reflections")

    /// The vault category, or `nil` for a value this version of the app does not know yet.
    public var category: VaultCategory? { VaultCategory(rawValue: rawValue) }
}

public struct AylaScreen: AylaValue {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let home = Self(rawValue: "home")
    public static let chat = Self(rawValue: "chat")
    public static let vault = Self(rawValue: "vault")
    public static let vaultItem = Self(rawValue: "vaultItem")
    public static let addEvidence = Self(rawValue: "addEvidence")
    public static let plans = Self(rawValue: "plans")
    public static let vacancies = Self(rawValue: "vacancies")
    public static let profile = Self(rawValue: "profile")
    public static let settings = Self(rawValue: "settings")
}

public struct AylaActionKind: AylaValue {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let addVaultItem = Self(rawValue: "addVaultItem")
    public static let updatePlan = Self(rawValue: "updatePlan")
    public static let draftProfile = Self(rawValue: "draftProfile")
    public static let requestValidation = Self(rawValue: "requestValidation")
}

public enum AylaDevice: String, Codable, Sendable {
    case watch
    case phone
    case web
}

public enum AylaInput: String, Codable, Sendable {
    case voice
    case text
}
