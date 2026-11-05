import Foundation

public actor MockAuthService: AuthService {
    public static let demoPassword = "PaveDemo!2026"
    public static let demoCode = "123456"
    public static let verifiedAccount = "ravi@student.example.edu"
    public static let newAccount = "new@student.example.edu"

    private let delay: Duration
    private var passwords: [String: String]
    private var accountsWithVerification: Set<String>
    private var currentAccount: String?
    private var resetAccount: String?
    private var resetVerified = false

    public init(delay: Duration = .seconds(1)) {
        self.delay = delay
        passwords = [
            Self.verifiedAccount: Self.demoPassword,
            Self.newAccount: Self.demoPassword,
        ]
        accountsWithVerification = [Self.verifiedAccount]
    }

    public func signIn(email: String, password: String) async throws -> SignInOutcome {
        try await simulateNetwork()
        let account = Self.normalized(email)
        guard passwords[account] == password else { throw AuthError.invalidCredentials }
        currentAccount = account
        return accountsWithVerification.contains(account) ? .needsVerification : .needsVerificationSetup
    }

    public func verify(code: String) async throws {
        try await simulateNetwork()
        guard currentAccount != nil || resetAccount != nil, code == Self.demoCode else { throw AuthError.invalidCode }
        if resetAccount != nil {
            resetVerified = true
        }
    }

    public func startVerificationSetup() async throws -> VerificationEnrollment {
        try await simulateNetwork()
        guard currentAccount != nil else { throw AuthError.invalidCredentials }
        return VerificationEnrollment(factorID: "mock-totp-factor", setupURI: nil, secret: nil)
    }

    public func confirmVerificationSetup(code: String) async throws {
        try await simulateNetwork()
        guard let account = currentAccount, code == Self.demoCode else { throw AuthError.invalidCode }
        accountsWithVerification.insert(account)
    }

    public func requestPasswordReset(email: String) async throws {
        try await simulateNetwork()
    }

    public func verifyPasswordResetCode(email: String, code: String) async throws -> PasswordResetOutcome {
        try await simulateNetwork()
        let account = Self.normalized(email)
        guard passwords[account] != nil, code == Self.demoCode else { throw AuthError.invalidEmailCode }
        resetAccount = account
        resetVerified = false
        return accountsWithVerification.contains(account) ? .needsVerification : .readyForNewPassword
    }

    public func updatePassword(_ newPassword: String) async throws {
        try await simulateNetwork()
        guard let account = resetAccount else { throw AuthError.resetSessionExpired }
        guard !accountsWithVerification.contains(account) || resetVerified else { throw AuthError.insufficientAssurance }
        guard PasswordRequirement.allMet(by: newPassword) else { throw AuthError.weakPassword }
        guard passwords[account] != newPassword else { throw AuthError.samePassword }
        passwords[account] = newPassword
        resetAccount = nil
        resetVerified = false
    }

    public func signOut() async {
        currentAccount = nil
        resetAccount = nil
        resetVerified = false
    }

    public func accountID() async -> String? {
        currentAccount
    }

    private func simulateNetwork() async throws {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
    }

    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
