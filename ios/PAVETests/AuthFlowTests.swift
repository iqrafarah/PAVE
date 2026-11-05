import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct AuthFlowTests {
    private final class SignInSpy {
        var didSignIn = false
        var accountID: String?
    }

    private let spy = SignInSpy()
    private let flow: AuthFlow

    init() {
        let spy = spy
        flow = AuthFlow(service: MockAuthService(delay: .zero)) { accountID in
            spy.didSignIn = true
            spy.accountID = accountID
        }
    }

    @Test func existingAccountGoesToVerificationAndSignsIn() async throws {
        try await flow.signIn(email: MockAuthService.verifiedAccount, password: MockAuthService.demoPassword)
        #expect(flow.path == [.verification])

        try await flow.verify(code: MockAuthService.demoCode)
        #expect(spy.didSignIn)
        #expect(spy.accountID == MockAuthService.verifiedAccount)
    }

    @Test func newAccountGoesThroughSetup() async throws {
        try await flow.signIn(email: MockAuthService.newAccount, password: MockAuthService.demoPassword)
        #expect(flow.path == [.verificationSetup])

        try await flow.confirmVerificationSetup(code: MockAuthService.demoCode)
        #expect(flow.path == [.verificationSetup, .verificationSetupComplete])
        #expect(!spy.didSignIn)

        flow.finishVerificationSetup()
        #expect(spy.didSignIn)
        #expect(spy.accountID == MockAuthService.newAccount)
    }

    @Test func wrongPasswordStaysOnSignIn() async {
        await #expect(throws: AuthError.invalidCredentials) {
            try await flow.signIn(email: MockAuthService.verifiedAccount, password: "wrong")
        }
        #expect(flow.path.isEmpty)
    }

    @Test func resendingResetLinkDoesNotStackScreens() async throws {
        flow.showForgotPassword()
        try await flow.requestPasswordReset(email: MockAuthService.verifiedAccount)
        try await flow.requestPasswordReset(email: MockAuthService.verifiedAccount)
        #expect(flow.path == [.forgotPassword, .resetEmailSent(email: MockAuthService.verifiedAccount)])
    }

    @Test func resetLinkOpensNewPasswordAndFinishes() async throws {
        await flow.openPasswordResetLink(URL(string: "pave://reset-password")!)
        #expect(flow.path == [.newPassword])

        try await flow.updatePassword("BrightFuture!2026")
        #expect(flow.path == [.newPassword, .passwordResetComplete])

        flow.returnToLogin()
        #expect(flow.path.isEmpty)
    }

    @Test func invalidLinkOffersNewResetRequest() async {
        await flow.openPasswordResetLink(URL(string: "pave://something-else")!)
        #expect(flow.path == [.forgotPassword])
    }
}
