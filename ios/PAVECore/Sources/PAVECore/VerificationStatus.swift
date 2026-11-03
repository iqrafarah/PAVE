public enum VerificationStatus: String, Codable, CaseIterable, Sendable {
    case verified
    case validated
    case selfAdded

    public var displayName: String {
        switch self {
        case .verified: "Geverifieerd"
        case .validated: "Gevalideerd"
        case .selfAdded: "Zelf toegevoegd"
        }
    }

    public var isExternallyConfirmed: Bool {
        self != .selfAdded
    }
}
