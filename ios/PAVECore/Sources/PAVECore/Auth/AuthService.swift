import Foundation

public protocol AuthService: Sendable {
    func signIn(email: String, password: String) async throws -> SignInOutcome
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
    case noConnection
    case unavailable

    public init(_ error: any Error) {
        self = (error as? AuthError) ?? .unavailable
    }
}
