import Foundation
import Testing
@testable import PAVECore

struct PasswordRequirementTests {
    @Test func strongPasswordMeetsEveryRequirement() {
        #expect(PasswordRequirement.allMet(by: "BrightFuture!2026"))
    }

    @Test(arguments: [
        ("Short!1a", PasswordRequirement.minimumLength),
        ("alllowercase!2026", .mixedCase),
        ("ALLUPPERCASE!2026", .mixedCase),
        ("NoSymbolsHere2026", .numberAndSymbol),
        ("NoNumbersHere!!!", .numberAndSymbol),
    ])
    func weakPasswordMissesRequirement(password: String, requirement: PasswordRequirement) {
        #expect(!requirement.isMet(by: password))
        #expect(!PasswordRequirement.allMet(by: password))
    }
}

struct MockAuthServiceTests {
    private let service = MockAuthService(delay: .zero)

    @Test func accountWithVerificationAsksForCode() async throws {
        let outcome = try await service.signIn(email: " Ravi@Student.example.edu ", password: MockAuthService.demoPassword)
        #expect(outcome == .needsVerification)
        try await service.verify(code: MockAuthService.demoCode)
    }

    @Test func newAccountAsksForSetup() async throws {
        let outcome = try await service.signIn(email: MockAuthService.newAccount, password: MockAuthService.demoPassword)
        #expect(outcome == .needsVerificationSetup)
        _ = try await service.startVerificationSetup()
        try await service.confirmVerificationSetup(code: MockAuthService.demoCode)

        await service.signOut()
        let nextOutcome = try await service.signIn(email: MockAuthService.newAccount, password: MockAuthService.demoPassword)
        #expect(nextOutcome == .needsVerification)
    }

    @Test func wrongPasswordIsRejected() async {
        await #expect(throws: AuthError.invalidCredentials) {
            try await service.signIn(email: MockAuthService.verifiedAccount, password: "wrong")
        }
    }

    @Test func wrongCodeIsRejected() async throws {
        _ = try await service.signIn(email: MockAuthService.verifiedAccount, password: MockAuthService.demoPassword)
        await #expect(throws: AuthError.invalidCode) {
            try await service.verify(code: "000000")
        }
    }

    @Test func resetLinkAllowsNewPassword() async throws {
        try await service.openPasswordResetLink(URL(string: "pave://reset-password")!)
        try await service.updatePassword("BrightFuture!2026")

        let outcome = try await service.signIn(email: MockAuthService.verifiedAccount, password: "BrightFuture!2026")
        #expect(outcome == .needsVerification)
    }

    @Test func updatingPasswordWithoutLinkFails() async {
        await #expect(throws: AuthError.invalidResetLink) {
            try await service.updatePassword("BrightFuture!2026")
        }
    }
}
