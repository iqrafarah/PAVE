import Foundation
import PAVECore
import Testing

/// SupabaseAuthService against the real auth server: sign-up, two-step verification, sign-in, sign-out and its errors.
@Suite(.localSupabase)
struct AuthIntegrationTests {
    private func freshAuth() -> SupabaseAuthService {
        SupabaseAuthService(projectURL: LocalSupabase.url, publishableKey: LocalSupabase.publishableKey, localStorage: MemoryAuthStorage())
    }

    @Test func aNewAccountWithTwoStepVerificationHasAnActiveSession() async throws {
        let user = try await TestUser.make("signup")
        #expect(await user.auth.accountID() != nil)
        #expect(await user.auth.accessToken() != nil)
        #expect(await user.auth.sessionState() == .active)
    }

    @Test func signingInAgainAsksForTheAuthenticatorCode() async throws {
        let user = try await TestUser.make("signin")
        await user.auth.signOut()

        let auth = freshAuth()
        let outcome = try await auth.signIn(email: user.email, password: LocalSupabase.password)
        #expect(outcome == .needsVerification)
        try await auth.verify(code: TOTP.code(secret: #require(user.totpSecret)))
        #expect(await auth.sessionState() == .active)
    }

    @Test func anAccountWithoutTwoStepIsAskedToSetItUp() async throws {
        let user = try await TestUser.make("nosetup", twoStep: false)
        let auth = freshAuth()
        #expect(try await auth.signIn(email: user.email, password: LocalSupabase.password) == .needsVerificationSetup)
    }

    @Test func aWrongPasswordIsRefused() async throws {
        let user = try await TestUser.make("wrongpw", twoStep: false)
        await #expect(throws: AuthError.invalidCredentials) {
            try await freshAuth().signIn(email: user.email, password: "Niet-het-wachtwoord1!")
        }
    }

    @Test func aWrongAuthenticatorCodeIsRefused() async throws {
        let user = try await TestUser.make("wrongcode")
        await user.auth.signOut()
        let auth = freshAuth()
        _ = try await auth.signIn(email: user.email, password: LocalSupabase.password)
        let right = try TOTP.code(secret: #require(user.totpSecret))
        let wrong = String(format: "%06d", (Int(right)! + 1) % 1_000_000)
        await #expect(throws: AuthError.invalidCode) { try await auth.verify(code: wrong) }
    }

    @Test func anAddressCanOnlyBeRegisteredOnce() async throws {
        let user = try await TestUser.make("twice", twoStep: false)
        await #expect(throws: AuthError.emailAlreadyRegistered) {
            try await freshAuth().signUp(email: user.email, password: LocalSupabase.password, firstName: "Test", lastName: "Twice")
        }
    }

    @Test func signingOutEndsTheSession() async throws {
        let user = try await TestUser.make("signout")
        await user.auth.signOut()
        #expect(await user.auth.accessToken() == nil)
        #expect(await user.auth.accountID() == nil)
    }
}
