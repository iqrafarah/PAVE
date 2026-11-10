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

struct PasswordInputTests {
    @Test(arguments: [
        ("BrightFuture!2026\n", "BrightFuture!2026"),
        ("BrightFuture!2026\r\n", "BrightFuture!2026"),
        ("\nBright\nFuture!2026", "BrightFuture!2026"),
        ("Bright Future!2026 ", "Bright Future!2026 "),
    ])
    func leavesOutLineBreaksButKeepsSpaces(pasted: String, kept: String) {
        #expect(PasswordInput.cleaned(pasted) == kept)
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

    @Test func resetCodeAllowsNewPassword() async throws {
        try await service.requestPasswordReset(email: MockAuthService.verifiedAccount)
        let resetOutcome = try await service.verifyPasswordResetCode(email: MockAuthService.verifiedAccount, code: MockAuthService.demoCode)
        #expect(resetOutcome == .needsVerification)
        try await service.verify(code: MockAuthService.demoCode)
        try await service.updatePassword("BrightFuture!2026")

        let outcome = try await service.signIn(email: MockAuthService.verifiedAccount, password: "BrightFuture!2026")
        #expect(outcome == .needsVerification)
    }

    @Test func wrongResetCodeIsRejected() async {
        await #expect(throws: AuthError.invalidEmailCode) {
            try await service.verifyPasswordResetCode(email: MockAuthService.verifiedAccount, code: "000000")
        }
    }

    @Test func unknownEmailCannotUseAResetCode() async {
        await #expect(throws: AuthError.invalidEmailCode) {
            try await service.verifyPasswordResetCode(email: "nobody@student.example.edu", code: MockAuthService.demoCode)
        }
    }

    @Test func updatingPasswordWithoutACodeFails() async {
        await #expect(throws: AuthError.resetSessionExpired) {
            try await service.updatePassword("BrightFuture!2026")
        }
    }

    @Test func accountWithVerificationNeedsTheCodeBeforeANewPassword() async throws {
        _ = try await service.verifyPasswordResetCode(email: MockAuthService.verifiedAccount, code: MockAuthService.demoCode)
        await #expect(throws: AuthError.insufficientAssurance) {
            try await service.updatePassword("BrightFuture!2026")
        }
    }

    @Test func accountWithoutVerificationGoesStraightToANewPassword() async throws {
        let outcome = try await service.verifyPasswordResetCode(email: MockAuthService.newAccount, code: MockAuthService.demoCode)
        #expect(outcome == .readyForNewPassword)
        try await service.updatePassword("BrightFuture!2026")
    }

    @Test func newPasswordMustDifferFromTheCurrentOne() async throws {
        _ = try await service.verifyPasswordResetCode(email: MockAuthService.verifiedAccount, code: MockAuthService.demoCode)
        try await service.verify(code: MockAuthService.demoCode)
        await #expect(throws: AuthError.samePassword) {
            try await service.updatePassword(MockAuthService.demoPassword)
        }
    }

    @Test func aResetCodeWorksOnlyOnce() async throws {
        _ = try await service.verifyPasswordResetCode(email: MockAuthService.verifiedAccount, code: MockAuthService.demoCode)
        try await service.verify(code: MockAuthService.demoCode)
        try await service.updatePassword("BrightFuture!2026")
        await #expect(throws: AuthError.resetSessionExpired) {
            try await service.updatePassword("AnotherStrong!2027")
        }
    }
}
