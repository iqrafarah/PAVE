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
            "PASSWORDS_DIFFER_MESSAGE": AuthMessages.passwordsDiffer,
            "PASSWORD_RULES_NOT_MET_MESSAGE": AuthMessages.passwordRulesNotMet,
            "UNKNOWN_ERROR_MESSAGE": AuthMessages.unknownError,
            "WRONG_AUTHENTICATOR_CODE_MESSAGE": AuthMessages.wrongAuthenticatorCode,
            "TOO_MANY_ATTEMPTS_MESSAGE": AuthMessages.tooManyAttempts,
            "NO_CONNECTION_MESSAGE": AuthMessages.noConnection,
            "INSUFFICIENT_AAL_MESSAGE": AuthMessages.insufficientAssurance,
            "SAME_PASSWORD_MESSAGE": AuthMessages.samePassword,
            "AUTHENTICATOR_HEADING": AuthMessages.authenticatorHeading,
            "AUTHENTICATOR_INSTRUCTION": AuthMessages.authenticatorInstruction,
            "AUTHENTICATOR_CODE_HINT": AuthMessages.authenticatorCodeHint,
            "AUTHENTICATOR_CODE_LABEL": AuthMessages.authenticatorCodeLabel,
            "EMAIL_CODE_LABEL": AuthMessages.emailCodeLabel,
            "LOGIN_INSTRUCTION": AuthMessages.loginInstruction,
            "RESET_EMAIL_INSTRUCTION": AuthMessages.resetEmailInstruction,
            "RESET_CODE_INSTRUCTION": AuthMessages.resetCodeInstruction,
            "NEW_PASSWORD_INSTRUCTION": AuthMessages.newPasswordInstruction,
            "WRONG_EMAIL_PROMPT": AuthMessages.wrongEmailPrompt,
            "WRONG_EMAIL_LINK": AuthMessages.wrongEmailLink,
            "RESEND_EMAIL_CODE_LABEL": AuthMessages.resendEmailCodeLabel,
            "EMAIL_CODE_RESENT_MESSAGE": AuthMessages.emailCodeResent,
            "PASSWORD_RULES_ALL_MET_MESSAGE": AuthMessages.passwordRulesAllMet,
            "PASSWORDS_MATCH_MESSAGE": AuthMessages.passwordsMatch,
            "PASSWORDS_NOT_EQUAL_MESSAGE": AuthMessages.passwordsNotEqual,
        ]
        for (name, text) in ios {
            #expect(web[name] == text, "\(name) differs from the web")
        }
    }

    @Test(.enabled(if: AuthMessagesTests.webIsAvailable))
    func textsWithAValueAreIdenticalToTheWeb() throws {
        let source = try String(contentsOf: Self.webRoot.appending(path: "messages.ts"), encoding: .utf8)
        let expected = [
            AuthMessages.resetCodeSent(to: "${maskedEmail}"),
            AuthMessages.resendCountdown(secondsLeft: 0).replacingOccurrences(of: "0", with: "${secondsLeft}"),
            AuthMessages.remainingRules(1),
            AuthMessages.remainingRules(2).replacingOccurrences(of: "2", with: "${remainingCount}"),
            "['" + AuthMessages.resetSteps.joined(separator: "', '") + "']",
            "['" + AuthMessages.resetStepsWithoutAuthenticator.joined(separator: "', '") + "']",
        ]
        for text in expected {
            #expect(source.contains(text), "\(text) differs from the web")
        }
        #expect(AuthMessages.remainingRules(0) == AuthMessages.passwordRulesAllMet)
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
