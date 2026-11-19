import Foundation

public protocol AuthService: Sendable {
    func signIn(email: String, password: String) async throws -> SignInOutcome
    /// "Maak je eduID aan" (web register): an account of your own, confirmed with a code from the e-mail.
    func signUp(email: String, password: String, firstName: String, lastName: String) async throws -> SignUpOutcome
    /// The 6-digit code from the sign-up e-mail; it confirms the address and signs in (two-step setup follows).
    func verifySignUpCode(email: String, code: String) async throws
    func resendSignUpCode(email: String) async throws
    func verify(code: String) async throws
    func startVerificationSetup() async throws -> VerificationEnrollment
    func confirmVerificationSetup(code: String) async throws
    func requestPasswordReset(email: String) async throws
    func verifyPasswordResetCode(email: String, code: String) async throws -> PasswordResetOutcome
    func updatePassword(_ newPassword: String) async throws
    func signOut() async
    func accountID() async -> String?
    /// The token of the current session, refreshed when needed. Used to call other Supabase services.
    func accessToken() async -> String?
    /// Asks the server whether this session still exists. It ends when the password was changed, for example on
    /// another device, or when the account was signed out everywhere.
    func sessionState() async -> SessionState
}

public enum SessionState: Equatable, Sendable {
    case active
    case ended
    /// No answer, for example without a connection: nothing changes.
    case unknown
}

/// After "Account aanmaken": a 6-digit code was mailed, or (with e-mail confirmation off) the account is signed in.
public enum SignUpOutcome: Equatable, Sendable {
    case needsEmailCode
    case signedIn
}

public enum SignInOutcome: Equatable, Sendable {
    case needsVerification
    case needsVerificationSetup
}

public enum PasswordResetOutcome: Equatable, Sendable {
    case readyForNewPassword
    /// The account has two-step verification: the authenticator code is needed before the password can change.
    case needsVerification
}

public struct VerificationEnrollment: Equatable, Sendable {
    public let factorID: String
    public let setupURI: URL?
    public let secret: String?

    public init(factorID: String, setupURI: URL?, secret: String?) {
        self.factorID = factorID
        self.setupURI = setupURI
        self.secret = secret
    }
}

public enum AuthError: Error, Equatable, Sendable, CaseIterable {
    case invalidCredentials
    case emailNotConfirmed
    case invalidCode
    case invalidEmailCode
    case requestedTooSoon
    case tooManyAttempts
    case insufficientAssurance
    case samePassword
    case weakPassword
    case resetSessionExpired
    case signupDisabled
    case emailAlreadyRegistered
    case invalidEmail
    case noConnection
    case unavailable

    public init(_ error: any Error) {
        self = (error as? AuthError) ?? .unavailable
    }
}
