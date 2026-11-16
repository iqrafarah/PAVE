import Foundation
import Observation
import PAVECore

enum AuthRoute: Hashable {
    case verification
    case verificationSetup
    case verificationSetupComplete
    case forgotPassword
    case resetCode(email: String)
    case resetVerification
    case newPassword
    case passwordResetComplete
}

@Observable
final class AuthFlow {
    var path: [AuthRoute] = []

    private let service: any AuthService
    private let onSignedIn: (String?) -> Void
    private var setupAccountID: String?

    init(service: any AuthService, onSignedIn: @escaping (String?) -> Void) {
        self.service = service
        self.onSignedIn = onSignedIn
    }

    func signIn(email: String, password: String) async throws {
        switch try await service.signIn(email: email, password: password) {
        case .needsVerification:
            path.append(.verification)
        case .needsVerificationSetup:
            path.append(.verificationSetup)
        }
    }

    func verify(code: String) async throws {
        try await service.verify(code: code)
        onSignedIn(await service.accountID())
    }

    func startVerificationSetup() async throws -> VerificationEnrollment {
        try await service.startVerificationSetup()
    }

    func confirmVerificationSetup(code: String) async throws {
        try await service.confirmVerificationSetup(code: code)
        setupAccountID = await service.accountID()
        path.append(.verificationSetupComplete)
    }

    func finishVerificationSetup() {
        onSignedIn(setupAccountID)
    }

    func showForgotPassword() {
        path.append(.forgotPassword)
    }

    func requestPasswordReset(email: String) async throws {
        try await service.requestPasswordReset(email: email)
        if path.last != .resetCode(email: email) {
            path.append(.resetCode(email: email))
        }
    }

    /// "Verkeerd e-mailadres? Terug": back to the email screen, which still holds what you typed.
    func returnToResetEmail() {
        if case .resetCode = path.last {
            path.removeLast()
        }
    }

    /// The steps of the password reset: with the authenticator code when the account needed it on the way.
    var resetSteps: [String] {
        path.contains(.resetVerification) ? AuthMessages.resetSteps : AuthMessages.resetStepsWithoutAuthenticator
    }

    func verifyPasswordResetCode(email: String, code: String) async throws {
        switch try await service.verifyPasswordResetCode(email: email, code: code) {
        case .readyForNewPassword:
            path.append(.newPassword)
        case .needsVerification:
            path.append(.resetVerification)
        }
    }

    func verifyForPasswordReset(code: String) async throws {
        try await service.verify(code: code)
        path.append(.newPassword)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await service.updatePassword(newPassword)
        path.append(.passwordResetComplete)
    }

    func returnToLogin() {
        path.removeAll()
        Task { await service.signOut() }
    }
}
