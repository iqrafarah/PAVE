import Foundation
import Security

/// What PAVE keeps to reach a mailbox: only in the Keychain of this iPhone, never on a server or in iCloud.
nonisolated struct EmailCredentials: Codable, Sendable {
    var account: EmailAccount
    /// The app-specific password.
    var secret: String
    /// The user name that logged in, the whole address or the part before the @.
    var loginName: String?
}

nonisolated struct EmailCredentialStore: Sendable {
    private let service: String

    init(service: String = "nl.fontys.pave.email") {
        self.service = service
    }

    func load(_ provider: EmailProvider) -> EmailCredentials? {
        var query = baseQuery(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(EmailCredentials.self, from: data)
    }

    func loadAll() -> [EmailCredentials] {
        EmailProvider.allCases.compactMap(load)
    }

    func save(_ credentials: EmailCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        delete(credentials.account.provider)
        var query = baseQuery(credentials.account.provider)
        query[kSecValueData as String] = data
        // Readable after the first unlock, so a background refresh can look for new mail; never synced or restored elsewhere.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw EmailError.server("Je gegevens konden niet veilig worden bewaard.") }
    }

    func delete(_ provider: EmailProvider) {
        SecItemDelete(baseQuery(provider) as CFDictionary)
    }

    func deleteAll() {
        EmailProvider.allCases.forEach(delete)
    }

    private func baseQuery(_ provider: EmailProvider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
    }
}
