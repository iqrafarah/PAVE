public enum PasswordRequirement: CaseIterable, Sendable {
    case minimumLength
    case mixedCase
    case numberAndSymbol

    public static let minimumCharacterCount = 12

    public func isMet(by password: String) -> Bool {
        switch self {
        case .minimumLength:
            password.count >= Self.minimumCharacterCount
        case .mixedCase:
            password.contains(where: \.isUppercase) && password.contains(where: \.isLowercase)
        case .numberAndSymbol:
            password.contains(where: \.isNumber)
                && password.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }
        }
    }

    public static let heading = "Eisen voor je wachtwoord:"

    /// Must equal the labels in `web/app/utils/passwordRules.ts`.
    public var title: String {
        switch self {
        case .minimumLength: "Minimaal \(Self.minimumCharacterCount) tekens"
        case .mixedCase: "Hoofdletters en kleine letters"
        case .numberAndSymbol: "Minimaal één cijfer en één symbool"
        }
    }

    public static func allMet(by password: String) -> Bool {
        allCases.allSatisfy { $0.isMet(by: password) }
    }
}
