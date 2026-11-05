import Foundation
import Testing
@testable import PAVECore

/// The web is the source of truth for every Dutch text of the login flow.
/// These tests read the web files and compare them with the texts used on iOS.
struct AuthMessagesTests {
    private static let webRoot = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "web/app/utils")

    private static var webIsAvailable: Bool {
        FileManager.default.fileExists(atPath: webRoot.appending(path: "messages.ts").path(percentEncoded: false))
    }

    private func webConstants() throws -> [String: String] {
        let source = try String(contentsOf: Self.webRoot.appending(path: "messages.ts"), encoding: .utf8)
        let pattern = #"export const (\w+) =\s*(['"])(.*?)\2;"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        var result: [String: String] = [:]
        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            guard let name = Range(match.range(at: 1), in: source), let value = Range(match.range(at: 3), in: source) else { continue }
            result[String(source[name])] = String(source[value]).replacingOccurrences(of: "\\'", with: "'")
        }
        return result
    }

    @Test(.enabled(if: AuthMessagesTests.webIsAvailable))
    func messagesAreIdenticalToTheWeb() throws {
        let web = try webConstants()
        let ios: [String: String] = [
            "LOGIN_FAILED_MESSAGE": AuthMessages.loginFailed,
            "INVALID_EMAIL_CODE_MESSAGE": AuthMessages.invalidEmailCode,
            "REQUESTED_TOO_SOON_MESSAGE": AuthMessages.requestedTooSoon,
            "RESET_REQUESTED_MESSAGE": AuthMessages.resetRequested,
            "PASSWORDS_DIFFER_MESSAGE": AuthMessages.passwordsDiffer,
            "PASSWORD_RULES_NOT_MET_MESSAGE": AuthMessages.passwordRulesNotMet,
            "UNKNOWN_ERROR_MESSAGE": AuthMessages.unknownError,
            "WRONG_AUTHENTICATOR_CODE_MESSAGE": AuthMessages.wrongAuthenticatorCode,
            "TOO_MANY_ATTEMPTS_MESSAGE": AuthMessages.tooManyAttempts,
            "NO_CONNECTION_MESSAGE": AuthMessages.noConnection,
            "INSUFFICIENT_AAL_MESSAGE": AuthMessages.insufficientAssurance,
            "SAME_PASSWORD_MESSAGE": AuthMessages.samePassword,
        ]
        for (name, text) in ios {
            #expect(web[name] == text, "\(name) differs from the web")
        }
    }

    @Test(.enabled(if: AuthMessagesTests.webIsAvailable))
    func supportAddressIsTheSameAsOnTheWeb() throws {
        let source = try String(contentsOf: Self.webRoot.appending(path: "constants.ts"), encoding: .utf8)
        #expect(source.contains("'\(PaveSupport.email)'"))
    }

    @Test(.enabled(if: AuthMessagesTests.webIsAvailable))
    func passwordRulesAreIdenticalToTheWeb() throws {
        let source = try String(contentsOf: Self.webRoot.appending(path: "passwordRules.ts"), encoding: .utf8)
        for requirement in PasswordRequirement.allCases {
            let expected = requirement.title.replacingOccurrences(of: "\(PasswordRequirement.minimumCharacterCount)", with: "${MIN_PASSWORD_LENGTH}")
            #expect(source.contains(expected), "\(requirement.title) differs from the web")
        }
    }

    @Test func everyErrorHasAMessage() {
        for error in AuthError.allCases {
            #expect(!error.message.isEmpty)
        }
    }
}
