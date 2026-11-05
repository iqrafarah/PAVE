import Auth
import Foundation
import Testing
@testable import PAVECore

struct SupabaseAuthServiceTests {
    @Test(arguments: [
        (ErrorCode.invalidCredentials, PAVECore.AuthError.invalidCredentials),
        (.emailNotConfirmed, .accountNotActive),
        (.userBanned, .accountNotActive),
        (.mfaVerificationFailed, .invalidCode),
        (.mfaChallengeExpired, .invalidCode),
        (.weakPassword, .weakPassword),
        (.samePassword, .weakPassword),
        (.otpExpired, .invalidResetLink),
        (.flowStateExpired, .invalidResetLink),
        (.overRequestRateLimit, .unavailable),
    ])
    func mapsSupabaseErrors(code: ErrorCode, expected: PAVECore.AuthError) {
        let error = Auth.AuthError.api(
            message: "",
            errorCode: code,
            underlyingData: Data(),
            underlyingResponse: HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 400, httpVersion: nil, headerFields: nil)!
        )
        #expect(SupabaseAuthService.authError(for: error) == expected)
    }

    @Test func normalizesEmailAddresses() {
        #expect(SupabaseAuthService.normalized("  Ravi@Student.Example.edu \n") == "ravi@student.example.edu")
    }

    @Test func networkErrorsAreUnavailable() {
        #expect(SupabaseAuthService.authError(for: URLError(.notConnectedToInternet)) == .unavailable)
    }

    @Test func rejectsForeignResetLinks() async {
        let service = SupabaseAuthService(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "test")
        await #expect(throws: PAVECore.AuthError.invalidResetLink) {
            try await service.openPasswordResetLink(URL(string: "https://evil.example.com/reset-password")!)
        }
    }
}
