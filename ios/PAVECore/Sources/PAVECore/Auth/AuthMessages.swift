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
    public static let resetRequested = "Als er een account bestaat voor dit e-mailadres, hebben we een code gestuurd."
    public static let passwordsDiffer = "De wachtwoorden zijn niet hetzelfde. Vul je nieuwe wachtwoord opnieuw in."
    public static let passwordRulesNotMet = "Je wachtwoord voldoet nog niet aan alle eisen."
    public static let unknownError = "Er ging iets mis. Probeer het later opnieuw."
    public static let wrongAuthenticatorCode = "Deze code klopt niet of is verlopen. Gebruik de nieuwste code uit je authenticator-app en probeer het opnieuw."
    public static let tooManyAttempts = "Je hebt te vaak geprobeerd. Wacht even en probeer het opnieuw."
    public static let noConnection = "We konden PAVE niet bereiken. Controleer je internetverbinding en probeer het opnieuw."
    public static let insufficientAssurance = "Bevestig eerst met een code uit je authenticator-app dat jij het bent."
    public static let samePassword = "Dit is je huidige wachtwoord. Kies een ander wachtwoord."

    public static let emailNotConfirmed = "Bevestig eerst je e-mailadres. Kijk in je mail voor de bevestigingslink."
    public static let setupCouldNotStart = "Het instellen kon niet starten. Ga terug naar inloggen en log opnieuw in."
}

extension AuthError {
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
