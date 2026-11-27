import Foundation

/// One thing a person keeps in PAVE that follows the account to every device (`account_state`, migration
/// 20261127120000): what kind of thing (`scope`), which one (`key`), and its value as JSON.
public struct AccountStateRow: Equatable, Sendable {
    public var scope: String
    public var key: String
    /// JSON, as the app wrote it.
    public var value: Data
    public var updatedAt: Date

    public init(scope: String, key: String, value: Data, updatedAt: Date) {
        self.scope = scope
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }

    public var id: String { "\(scope)/\(key)" }
}

public protocol AccountStateService: Sendable {
    func all() async throws -> [AccountStateRow]
    func save(_ rows: [AccountStateRow]) async throws
}

public enum AccountStateServiceError: Error, Equatable, Sendable {
    /// The table does not exist yet: everything stays on the device, per account.
    case notSetUp
    case noSession
    case failed(status: Int)
}

/// How two copies of one thing come together: the newest wins, or (for lists of what was seen, and choices per
/// proposal) both together, so nothing seen on one device turns unseen by the other.
public enum AccountStateMerge: Sendable {
    case newest
    /// Lists of strings: every item of both.
    case unionOfStrings
    /// Objects: every key of both; for a key in both, the newest copy's value.
    case unionOfKeys
    /// A moment: the latest one.
    case latestDate
    /// A list of objects with a "date": every one of both, once, sorted by date.
    case unionByDate

    /// The value both devices then keep, from the local copy and the account's, each with when it changed.
    public func merge(local: Any?, localAt: Date?, remote: Any?, remoteAt: Date?) -> Any? {
        guard let local else { return remote }
        guard let remote else { return local }
        let localIsNewer = (localAt ?? .distantPast) > (remoteAt ?? .distantPast)
        switch self {
        case .newest:
            return localIsNewer ? local : remote
        case .unionOfStrings:
            let a = local as? [String] ?? [], b = remote as? [String] ?? []
            var seen = Set<String>()
            return (a + b).filter { seen.insert($0).inserted }
        case .unionOfKeys:
            let a = local as? [String: Any] ?? [:], b = remote as? [String: Any] ?? [:]
            return localIsNewer ? b.merging(a) { _, mine in mine } : a.merging(b) { _, theirs in theirs }
        case .latestDate:
            let a = (local as? String).flatMap(Self.date), b = (remote as? String).flatMap(Self.date)
            guard let a else { return remote }
            guard let b else { return local }
            return a >= b ? local : remote
        case .unionByDate:
            let a = local as? [[String: Any]] ?? [], b = remote as? [[String: Any]] ?? []
            var seen = Set<String>()
            let all = (a + b).filter { entry in
                guard let json = try? JSONSerialization.data(withJSONObject: entry, options: .sortedKeys) else { return false }
                return seen.insert(String(decoding: json, as: UTF8.self)).inserted
            }
            return all.sorted { Self.sortKey($0["date"]) < Self.sortKey($1["date"]) }
        }
    }

    private static func date(_ text: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)) ?? (try? Date.ISO8601FormatStyle().parse(text))
    }

    private static func sortKey(_ value: Any?) -> Double {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let text = value as? String { return date(text)?.timeIntervalSince1970 ?? 0 }
        return 0
    }
}
