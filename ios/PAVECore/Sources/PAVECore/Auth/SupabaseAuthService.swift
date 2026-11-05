import Auth
import Foundation
import OSLog

public struct SupabaseAuthService: AuthService {
    public static let passwordResetRedirect = URL(string: "pave://reset-password")!

    private static let logger = Logger(subsystem: "nl.fontys.pave", category: "auth")

    private let client: AuthClient

    public init(projectURL: URL, publishableKey: String) {
        client = AuthClient(
            url: projectURL.appending(path: "auth/v1"),
            headers: ["apikey": publishableKey],
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
            try await client.resetPasswordForEmail(Self.normalized(email), redirectTo: Self.passwordResetRedirect)
        }
    }

    public func openPasswordResetLink(_ url: URL) async throws {
        guard url.scheme == Self.passwordResetRedirect.scheme, url.host() == Self.passwordResetRedirect.host() else {
            throw AuthError.invalidResetLink
        }
        do {
            try await client.session(from: url)
        } catch {
            throw AuthError.invalidResetLink
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

    static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func authError(for error: any Error) -> AuthError {
        guard let supabaseError = error as? Auth.AuthError else { return .unavailable }
        switch supabaseError.errorCode {
        case .invalidCredentials:
            return .invalidCredentials
        case .emailNotConfirmed, .userBanned:
            return .accountNotActive
        case .mfaVerificationFailed, .mfaVerificationRejected, .mfaChallengeExpired:
            return .invalidCode
        case .weakPassword, .samePassword:
            return .weakPassword
        case .otpExpired, .flowStateExpired, .badCodeVerifier, .sessionNotFound:
            return .invalidResetLink
        default:
            return .unavailable
        }
    }
}
