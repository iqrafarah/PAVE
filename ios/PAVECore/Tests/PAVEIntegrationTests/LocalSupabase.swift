import Auth
import CryptoKit
import Foundation
import PAVECore
import Testing

/// The local stack from `supabase start` in shared/. These are the fixed development keys every local Supabase uses;
/// they open nothing outside this machine.
enum LocalSupabase {
    static let url = URL(string: ProcessInfo.processInfo.environment["PAVE_SUPABASE_URL"] ?? "http://127.0.0.1:55321")!
    static let publishableKey = ProcessInfo.processInfo.environment["PAVE_SUPABASE_KEY"] ?? "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
    static let password = "PaveTest!2026"

    /// Off by default, so `swift test` and ⌘U stay fast and offline.
    static let isEnabled = ProcessInfo.processInfo.environment["PAVE_INTEGRATION"] == "1"

    static func uniqueEmail(_ tag: String) -> String {
        "\(tag)-\(UUID().uuidString.prefix(8).lowercased())@pave.test"
    }
}

/// Swift Testing trait: skip the suite unless PAVE_INTEGRATION=1.
extension Trait where Self == ConditionTrait {
    static var localSupabase: Self {
        .enabled(if: LocalSupabase.isEnabled, "Set PAVE_INTEGRATION=1 with local Supabase running (see README.md)")
    }
}

/// A fresh account on the local stack, with its own session (not the Keychain), so several can be signed in at once.
struct TestUser: Sendable {
    let email: String
    let auth: SupabaseAuthService
    /// The authenticator secret, when two-step verification is set up.
    let totpSecret: String?

    /// Signs up a new account. With `twoStep` it also sets up the authenticator, so the session is aal2 like a real user's.
    static func make(_ tag: String = "user", twoStep: Bool = true) async throws -> TestUser {
        let email = LocalSupabase.uniqueEmail(tag)
        let auth = SupabaseAuthService(
            projectURL: LocalSupabase.url,
            publishableKey: LocalSupabase.publishableKey,
            localStorage: MemoryAuthStorage()
        )
        let outcome = try await auth.signUp(email: email, password: LocalSupabase.password, firstName: "Test", lastName: tag)
        #expect(outcome == .signedIn, "Local e-mail confirmation should be off (config.toml)")
        guard twoStep else { return TestUser(email: email, auth: auth, totpSecret: nil) }

        let enrollment = try await auth.startVerificationSetup()
        let secret = try #require(enrollment.secret)
        try await auth.confirmVerificationSetup(code: TOTP.code(secret: secret))
        return TestUser(email: email, auth: auth, totpSecret: secret)
    }

    var accessToken: @Sendable () async -> String? { { [auth] in await auth.accessToken() } }

    var vault: SupabaseVaultService {
        SupabaseVaultService(projectURL: LocalSupabase.url, publishableKey: LocalSupabase.publishableKey, accessToken: accessToken)
    }

    var plans: SupabasePlanService {
        SupabasePlanService(projectURL: LocalSupabase.url, publishableKey: LocalSupabase.publishableKey, accessToken: accessToken)
    }

    var profile: SupabaseProfileService {
        SupabaseProfileService(projectURL: LocalSupabase.url, publishableKey: LocalSupabase.publishableKey, accessToken: accessToken)
    }

    var ayla: SupabaseAylaService {
        SupabaseAylaService(projectURL: LocalSupabase.url, publishableKey: LocalSupabase.publishableKey, accessToken: accessToken)
    }
}

/// Keeps one session in memory: every test user gets their own.
final class MemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}

/// The 6-digit authenticator code (RFC 6238, SHA-1, 30 seconds), as an authenticator app would show it.
enum TOTP {
    static func code(secret: String, at date: Date = .now) throws -> String {
        let key = try #require(base32Decode(secret), "Not a base32 secret")
        var counter = UInt64(date.timeIntervalSince1970 / 30).bigEndian
        let message = Data(bytes: &counter, count: 8)
        let mac = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: SymmetricKey(data: key)))
        let offset = Int(mac[mac.count - 1] & 0x0f)
        let value = (UInt32(mac[offset] & 0x7f) << 24) | (UInt32(mac[offset + 1]) << 16)
            | (UInt32(mac[offset + 2]) << 8) | UInt32(mac[offset + 3])
        return String(format: "%06u", value % 1_000_000)
    }

    static func base32Decode(_ text: String) -> Data? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var bits = 0
        var buffer: UInt32 = 0
        var bytes = [UInt8]()
        for character in text.uppercased() where character != "=" {
            guard let index = alphabet.firstIndex(of: character) else { return nil }
            buffer = (buffer << 5) | UInt32(index)
            bits += 5
            if bits >= 8 {
                bits -= 8
                bytes.append(UInt8((buffer >> UInt32(bits)) & 0xff))
            }
        }
        return Data(bytes)
    }
}
