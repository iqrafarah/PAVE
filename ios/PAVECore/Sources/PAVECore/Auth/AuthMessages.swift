/// The Dutch texts of the login flow.
///
/// These must be identical to `web/app/utils/messages.ts`. The web is the source of truth:
/// when a text changes there, change it here too. `AuthMessagesTests` compares them.
public enum PaveSupport {
    public static let email = "support@pave.com"
}

public enum AuthMessages {
    public static let loginFailed = "Je e-mailadres of wachtwoord klopt niet. Probeer het opnieuw of kies 'Wachtwoord vergeten?'."
    public static let invalidEmailCode = "Deze code klopt niet of is verlopen. Vraag een nieuwe code aan."
    public static let requestedTooSoon = "Je hebt net al een code aangevraagd. Wacht 60 seconden en probeer het opnieuw."
    public static let passwordsDiffer = "De wachtwoorden zijn niet hetzelfde. Vul je nieuwe wachtwoord opnieuw in."
    public static let passwordRulesNotMet = "Je wachtwoord voldoet nog niet aan alle eisen."
    public static let unknownError = "Er ging iets mis. Probeer het later opnieuw."
    public static let wrongAuthenticatorCode = "Deze code klopt niet of is verlopen. Gebruik de nieuwste code uit je authenticator-app en probeer het opnieuw."
    public static let tooManyAttempts = "Je hebt te vaak geprobeerd. Wacht even en probeer het opnieuw."
    public static let noConnection = "We konden PAVE niet bereiken. Controleer je internetverbinding en probeer het opnieuw."
    public static let insufficientAssurance = "Bevestig eerst met een code uit je authenticator-app dat jij het bent."
    public static let samePassword = "Dit is je huidige wachtwoord. Kies een ander wachtwoord."

    public static let authenticatorHeading = "Open je authenticator-app"
    public static let authenticatorInstruction = "Vul de code uit de app in."
    public static let authenticatorCodeHint = "Je krijgt deze code niet per e-mail."
    public static let authenticatorCodeLabel = "Code uit je authenticator-app"
    public static let emailCodeLabel = "Code uit je e-mail"

    public static let resetSteps = ["E-mail", "Code uit e-mail", "Authenticator-code", "Nieuw wachtwoord"]
    public static let resetStepsWithoutAuthenticator = ["E-mail", "Code uit e-mail", "Nieuw wachtwoord"]

    public static let loginInstruction = "Vul je e-mailadres en wachtwoord in."
    public static let resetEmailInstruction = "Vul je e-mailadres in."
    public static let resetCodeInstruction = "Vul de code uit je e-mail in."
    public static let newPasswordInstruction = "Let op de eisen hieronder."
    public static let wrongEmailPrompt = "Verkeerd e-mailadres?"
    public static let wrongEmailLink = "Terug"
    public static let resendEmailCodeLabel = "Nieuwe code versturen"
    public static let emailCodeResent = "We hebben een nieuwe code naar je e-mail gestuurd."

    public static func resetCodeSent(to maskedEmail: String) -> String {
        "Als er een account bestaat voor \(maskedEmail), hebben we daar een code naartoe gestuurd."
    }

    public static func resendCountdown(secondsLeft: Int) -> String {
        "Nieuwe code versturen kan over \(secondsLeft) seconden"
    }

    public static let passwordRulesAllMet = "Je wachtwoord voldoet aan alle eisen"
    public static let passwordsMatch = "De wachtwoorden zijn hetzelfde."
    public static let passwordsNotEqual = "De wachtwoorden zijn niet gelijk."

    public static func remainingRules(_ count: Int) -> String {
        switch count {
        case 0: passwordRulesAllMet
        case 1: "Nog 1 eis te gaan"
        default: "Nog \(count) eisen te gaan"
        }
    }

    // iOS only. The web blocks pasting in the repeat field and says so; iOS lets Apple's strong-password suggestion
    // fill both fields, so it only asks to type the password again.
    public static let repeatPasswordHint = "Typ je wachtwoord nog een keer."
    // iOS only: the iPhone sets up two steps, the web three.
    public static let verificationSetupInstruction = "Volg de 2 stappen hieronder."

    public static let emailNotConfirmed = "Bevestig eerst je e-mailadres. Kijk in je mail voor de bevestigingslink."
    public static let setupCouldNotStart = "Het instellen kon niet starten. Ga terug naar inloggen en log opnieuw in."
}

extension AuthError {
    /// Every text an error can show, so a screen can keep room for the longest one.
    public static var allMessages: [String] { allCases.map(\.message) }

    /// Same mapping as `web/app/utils/authErrors.ts`.
    public var message: String {
        switch self {
        case .invalidCredentials: AuthMessages.loginFailed
        case .emailNotConfirmed: AuthMessages.emailNotConfirmed
        case .invalidCode: AuthMessages.wrongAuthenticatorCode
        case .invalidEmailCode: AuthMessages.invalidEmailCode
        case .requestedTooSoon: AuthMessages.requestedTooSoon
        case .tooManyAttempts: AuthMessages.tooManyAttempts
        case .insufficientAssurance: AuthMessages.insufficientAssurance
        case .samePassword: AuthMessages.samePassword
        case .weakPassword: AuthMessages.passwordRulesNotMet
        case .noConnection: AuthMessages.noConnection
        case .resetSessionExpired, .unavailable: AuthMessages.unknownError
        }
    }
}
