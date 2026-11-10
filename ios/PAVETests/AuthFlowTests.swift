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

    @Test func resendingResetCodeDoesNotStackScreens() async throws {
        flow.showForgotPassword()
        try await flow.requestPasswordReset(email: MockAuthService.verifiedAccount)
        try await flow.requestPasswordReset(email: MockAuthService.verifiedAccount)
        #expect(flow.path == [.forgotPassword, .resetCode(email: MockAuthService.verifiedAccount)])
    }

    @Test func resetWithTwoStepVerificationAsksForTheAuthenticatorCode() async throws {
        flow.showForgotPassword()
        try await flow.requestPasswordReset(email: MockAuthService.verifiedAccount)
        try await flow.verifyPasswordResetCode(email: MockAuthService.verifiedAccount, code: MockAuthService.demoCode)
        #expect(flow.path.last == .resetVerification)

        try await flow.verifyForPasswordReset(code: MockAuthService.demoCode)
        #expect(flow.path.last == .newPassword)
        #expect(!spy.didSignIn)

        try await flow.updatePassword("BrightFuture!2026")
        #expect(flow.path.last == .passwordResetComplete)
    }

    @Test func resetCodeOpensNewPasswordAndFinishes() async throws {
        flow.showForgotPassword()
        try await flow.requestPasswordReset(email: MockAuthService.newAccount)
        try await flow.verifyPasswordResetCode(email: MockAuthService.newAccount, code: MockAuthService.demoCode)
        #expect(flow.path.last == .newPassword)

        try await flow.updatePassword("BrightFuture!2026")
        #expect(flow.path.last == .passwordResetComplete)

        flow.returnToLogin()
        #expect(flow.path.isEmpty)
    }

    @Test func resetStepsIncludeTheAuthenticatorOnlyWhenItWasAsked() async throws {
        flow.showForgotPassword()
        try await flow.requestPasswordReset(email: MockAuthService.verifiedAccount)
        try await flow.verifyPasswordResetCode(email: MockAuthService.verifiedAccount, code: MockAuthService.demoCode)
        try await flow.verifyForPasswordReset(code: MockAuthService.demoCode)
        #expect(flow.resetSteps == AuthMessages.resetSteps)

        let other = AuthFlow(service: MockAuthService(delay: .zero)) { _ in }
        other.showForgotPassword()
        try await other.requestPasswordReset(email: MockAuthService.newAccount)
        try await other.verifyPasswordResetCode(email: MockAuthService.newAccount, code: MockAuthService.demoCode)
        #expect(other.resetSteps == AuthMessages.resetStepsWithoutAuthenticator)
    }

    @Test func wrongEmailGoesBackToTheEmailScreen() async throws {
        flow.showForgotPassword()
        try await flow.requestPasswordReset(email: MockAuthService.verifiedAccount)
        flow.returnToResetEmail()
        #expect(flow.path == [.forgotPassword])

        flow.returnToResetEmail()
        #expect(flow.path == [.forgotPassword])
    }

    @Test(arguments: [
        ("Authenticator-code", "Authenticator-\u{200B}code"),
        ("Code uit e-mail", "Code uit e-mail"),
        ("Nieuw wachtwoord", "Nieuw wachtwoord"),
    ])
    func longStepLabelsBreakAfterTheHyphen(title: String, shown: String) {
        #expect(AuthSteps.breakingAfterHyphen(title) == shown)
    }

    @Test func titlesKeepAHyphenatedWordTogether() {
        #expect(AuthIntro.keepingHyphenatedWordsWhole("Open je authenticator-app") == "Open je authenticator\u{2060}-\u{2060}app")
        #expect(AuthIntro.keepingHyphenatedWordsWhole("Check je inbox") == "Check je inbox")
    }

    @Test func wrongResetCodeStaysOnTheCodeScreen() async throws {
        flow.showForgotPassword()
        try await flow.requestPasswordReset(email: MockAuthService.verifiedAccount)
        await #expect(throws: AuthError.invalidEmailCode) {
            try await flow.verifyPasswordResetCode(email: MockAuthService.verifiedAccount, code: "000000")
        }
        #expect(flow.path.last == .resetCode(email: MockAuthService.verifiedAccount))
    }
}
