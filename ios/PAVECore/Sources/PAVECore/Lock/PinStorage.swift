import Foundation
import Security
import Synchronization

public protocol PinStorage: Sendable {
    func load() -> Data?
    func save(_ data: Data) throws
    func delete()
}

public enum PinVaultError: Error, Equatable, Sendable {
    case unacceptablePin
    case storageFailed
}

public final class InMemoryPinStorage: PinStorage {
    private let stored = Mutex<Data?>(nil)

    public init() {}

    public func load() -> Data? {
        stored.withLock { $0 }
    }

    public func save(_ data: Data) throws {
        stored.withLock { $0 = data }
    }

    public func delete() {
        stored.withLock { $0 = nil }
    }
}

public struct KeychainPinStorage: PinStorage {
    private let service: String
    private let account: String

    public init(service: String = "nl.fontys.pave.app-lock", account: String = "pin-record") {
        self.service = service
        self.account = account
    }

    public func load() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    public func save(_ data: Data) throws {
        delete()
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw PinVaultError.storageFailed
        }
    }

    public func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
