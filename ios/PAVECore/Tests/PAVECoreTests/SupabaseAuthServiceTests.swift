import Auth
import Foundation
import Testing
@testable import PAVECore

struct SupabaseAuthServiceTests {
    @Test(arguments: [
        (ErrorCode.invalidCredentials, PAVECore.AuthError.invalidCredentials),
        (.emailNotConfirmed, .emailNotConfirmed),
        (.userBanned, .unavailable),
        (.mfaVerificationFailed, .invalidCode),
        (.mfaChallengeExpired, .invalidCode),
        (.weakPassword, .weakPassword),
        (.samePassword, .samePassword),
        (.otpExpired, .invalidEmailCode),
        (.flowStateExpired, .resetSessionExpired),
        (.sessionNotFound, .resetSessionExpired),
        (.overRequestRateLimit, .tooManyAttempts),
        (.overEmailSendRateLimit, .requestedTooSoon),
        (.insufficientAAL, .insufficientAssurance),
        (.validationFailed, .unavailable),
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

}

extension SupabaseAuthServiceTests {
    @Test func networkErrorsAreNoConnection() {
        #expect(SupabaseAuthService.authError(for: URLError(.notConnectedToInternet)) == .noConnection)
    }

    @Test(arguments: [
        (ErrorCode.sessionNotFound, SessionState.ended),
        (.refreshTokenNotFound, .ended),
        (.refreshTokenAlreadyUsed, .ended),
        (.userNotFound, .ended),
        (.userBanned, .ended),
        (.overRequestRateLimit, .unknown),
        (.unexpectedFailure, .unknown),
    ])
    func knowsWhenTheSessionEnded(code: ErrorCode, expected: SessionState) {
        let error = Auth.AuthError.api(
            message: "",
            errorCode: code,
            underlyingData: Data(),
            underlyingResponse: HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 403, httpVersion: nil, headerFields: nil)!
        )
        #expect(SupabaseAuthService.sessionState(after: error) == expected)
    }

    @Test func aRemovedSessionOrNoConnection() {
        #expect(SupabaseAuthService.sessionState(after: Auth.AuthError.sessionMissing) == .ended)
        #expect(SupabaseAuthService.sessionState(after: URLError(.notConnectedToInternet)) == .unknown)
    }
}
