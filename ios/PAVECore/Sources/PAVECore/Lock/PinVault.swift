import CommonCrypto
import Foundation

public enum PinCheckResult: Equatable, Sendable {
    case correct
    case incorrect(attemptsRemaining: Int)
    case lockedOut
}

public struct PinVault: Sendable {
    public static let maximumAttempts = 5

    private struct Record: Codable {
        var salt: Data
        var hash: Data
        var failedAttempts: Int
        var biometricsEnabled: Bool
        var accountID: String?
    }

    private let storage: any PinStorage

    public init(storage: any PinStorage) {
        self.storage = storage
    }

    public var hasPin: Bool {
        record() != nil
    }

    public var isBiometricsEnabled: Bool {
        record()?.biometricsEnabled ?? false
    }

    public func belongs(to accountID: String) -> Bool {
        record()?.accountID == accountID
    }

    public func setPin(_ pin: String, biometricsEnabled: Bool, accountID: String? = nil) throws {
        guard PinPolicy.isAcceptable(pin) else { throw PinVaultError.unacceptablePin }
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        try save(Record(salt: salt, hash: Self.hash(pin, salt: salt), failedAttempts: 0, biometricsEnabled: biometricsEnabled, accountID: accountID))
    }

    public func check(_ pin: String) -> PinCheckResult {
        guard var record = record() else { return .lockedOut }

        if Self.constantTimeEqual(Self.hash(pin, salt: record.salt), record.hash) {
            if record.failedAttempts > 0 {
                record.failedAttempts = 0
                try? save(record)
            }
            return .correct
        }

        record.failedAttempts += 1
        if record.failedAttempts >= Self.maximumAttempts {
            clear()
            return .lockedOut
        }
        try? save(record)
        return .incorrect(attemptsRemaining: Self.maximumAttempts - record.failedAttempts)
    }

    public func clear() {
        storage.delete()
    }

    private func record() -> Record? {
        storage.load().flatMap { try? JSONDecoder().decode(Record.self, from: $0) }
    }

    private func save(_ record: Record) throws {
        try storage.save(JSONEncoder().encode(record))
    }

    private static func hash(_ pin: String, salt: Data) -> Data {
        var derived = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { saltBytes in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                pin, pin.utf8.count,
                saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                120_000,
                &derived, derived.count
            )
        }
        precondition(status == kCCSuccess, "PBKDF2 failed")
        return Data(derived)
    }

    private static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}
