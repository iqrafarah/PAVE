import Auth
import Foundation
import OSLog

public struct SupabaseAuthService: AuthService {
    private static let logger = Logger(subsystem: "nl.fontys.pave", category: "auth")

    private let client: AuthClient

    /// `userAgent` names this app in the list of signed-in devices, such as "PAVE-iOS/0.1 (iPhone; iOS 26.1)".
    public init(projectURL: URL, publishableKey: String, userAgent: String? = nil) {
        var headers = ["apikey": publishableKey]
        if let userAgent { headers["User-Agent"] = userAgent }
        client = AuthClient(
            url: projectURL.appending(path: "auth/v1"),
            headers: headers,
            localStorage: KeychainLocalStorage(),
            emitLocalSessionAsInitialSession: true
        )
    }

    public func signIn(email: String, password: String) async throws -> SignInOutcome {
        try await mapErrors {
            try await client.signIn(email: Self.normalized(email), password: password)
            let hasVerifiedFactor = try await !verifiedFactors().isEmpty
            return hasVerifiedFactor ? .needsVerification : .needsVerificationSetup
        }
    }

    public func verify(code: String) async throws {
        try await mapErrors {
            guard let factor = try await verifiedFactors().first else {
                throw AuthError.invalidCode
            }
            try await client.mfa.challengeAndVerify(params: MFAChallengeAndVerifyParams(factorId: factor.id, code: code))
        }
    }

    public func startVerificationSetup() async throws -> VerificationEnrollment {
        try await mapErrors {
            for factor in try await pendingFactors() {
                try await client.mfa.unenroll(params: MFAUnenrollParams(factorId: factor.id))
            }
            let enrollment = try await client.mfa.enroll(params: MFATotpEnrollParams(issuer: "PAVE"))
            return VerificationEnrollment(
                factorID: enrollment.id,
                setupURI: enrollment.totp.flatMap { URL(string: $0.uri) },
                secret: enrollment.totp?.secret
            )
        }
    }

    public func confirmVerificationSetup(code: String) async throws {
        try await mapErrors {
            guard let factor = try await pendingFactors().max(by: { $0.createdAt < $1.createdAt }) else {
                throw AuthError.invalidCode
            }
            try await client.mfa.challengeAndVerify(params: MFAChallengeAndVerifyParams(factorId: factor.id, code: code))
        }
    }

    public func requestPasswordReset(email: String) async throws {
        try await mapErrors {
            try await client.resetPasswordForEmail(Self.normalized(email))
        }
    }

    public func verifyPasswordResetCode(email: String, code: String) async throws -> PasswordResetOutcome {
        try await mapErrors {
            try await client.verifyOTP(email: Self.normalized(email), token: code, type: .recovery)
            let hasVerifiedFactor = try await !verifiedFactors().isEmpty
            return hasVerifiedFactor ? .needsVerification : .readyForNewPassword
        }
    }

    public func updatePassword(_ newPassword: String) async throws {
        try await mapErrors {
            try await client.update(user: UserAttributes(password: newPassword))
        }
        await signOut()
    }

    public func signOut() async {
        try? await client.signOut(scope: .local)
    }

    public func accountID() async -> String? {
        client.currentUser?.id.uuidString
    }

    public func accessToken() async -> String? {
        try? await client.session.accessToken
    }

    public func sessionState() async -> SessionState {
        do {
            _ = try await client.user()
            return .active
        } catch {
            return Self.sessionState(after: error)
        }
    }

    private func mapErrors<Value>(
        function: StaticString = #function,
        _ operation: () async throws -> Value
    ) async throws -> Value {
        do {
            return try await operation()
        } catch let error as AuthError {
            throw error
        } catch {
            Self.log(error, in: function)
            throw Self.authError(for: error)
        }
    }

    private static func log(_ error: any Error, in function: StaticString) {
        if let supabaseError = error as? Auth.AuthError {
            logger.error("\(function, privacy: .public) failed: \(supabaseError.errorCode.rawValue, privacy: .public) - \(supabaseError.message, privacy: .public)")
        } else {
            logger.error("\(function, privacy: .public) failed: \(String(describing: type(of: error)), privacy: .public) - \(error.localizedDescription, privacy: .public)")
        }
    }

    private func pendingFactors() async throws -> [Factor] {
        try await totpFactors(withStatus: .unverified)
    }

    private func verifiedFactors() async throws -> [Factor] {
        try await totpFactors(withStatus: .verified)
    }

    private func totpFactors(withStatus status: FactorStatus) async throws -> [Factor] {
        // `mfa.listFactors()` reads the user stored at sign-in. That copy can miss factors enrolled elsewhere
        // (for example on the web), so always ask the server.
        let user = try await client.user()
        return (user.factors ?? []).filter { $0.factorType == "totp" && $0.status == status }
    }

    /// The server removes a session when the password changes; the client then reports it as missing.
    static func sessionState(after error: any Error) -> SessionState {
        guard let supabaseError = error as? Auth.AuthError else { return .unknown }
        switch supabaseError.errorCode {
        case .sessionNotFound, .sessionExpired, .refreshTokenNotFound, .refreshTokenAlreadyUsed, .userNotFound, .userBanned:
            return .ended
        default:
            return .unknown
        }
    }

    static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func authError(for error: any Error) -> AuthError {
        if error is URLError { return .noConnection }
        guard let supabaseError = error as? Auth.AuthError else { return .unavailable }
        switch supabaseError.errorCode {
        case .invalidCredentials:
            return .invalidCredentials
        case .emailNotConfirmed:
            return .emailNotConfirmed
        case .mfaVerificationFailed, .mfaVerificationRejected, .mfaChallengeExpired:
            return .invalidCode
        case .weakPassword:
            return .weakPassword
        case .samePassword:
            return .samePassword
        case .otpExpired:
            return .invalidEmailCode
        case .flowStateExpired, .badCodeVerifier, .sessionNotFound:
            return .resetSessionExpired
        case .overEmailSendRateLimit:
            return .requestedTooSoon
        case .overRequestRateLimit:
            return .tooManyAttempts
        case .insufficientAAL:
            return .insufficientAssurance
        default:
            if case .api(_, _, _, let response) = supabaseError, response.statusCode == 429 {
                return .tooManyAttempts
            }
            return .unavailable
        }
    }
}
