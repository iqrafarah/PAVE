import Foundation
import Observation
import PAVECore

enum AuthRoute: Hashable {
    case verification
    case verificationSetup
    case verificationSetupComplete
    case forgotPassword
    case resetEmailSent(email: String)
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
        if path.last != .resetEmailSent(email: email) {
            path.append(.resetEmailSent(email: email))
        }
    }

    func openPasswordResetLink(_ url: URL) async {
        do {
            try await service.openPasswordResetLink(url)
            path = [.newPassword]
        } catch {
            path = [.forgotPassword]
        }
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
