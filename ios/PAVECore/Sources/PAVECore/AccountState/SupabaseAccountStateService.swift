import Foundation

/// `account_state` in Supabase (migration 20261127120000), with the user's own session, so row level security decides
/// what can be read and changed. Values are kept whole, as the app writes them.
public struct SupabaseAccountStateService: AccountStateService {
    private let tableURL: URL
    private let publishableKey: String
    private let session: URLSession
    private let accessToken: @Sendable () async -> String?

    public init(projectURL: URL, publishableKey: String, session: URLSession = .shared, accessToken: @escaping @Sendable () async -> String?) {
        tableURL = projectURL.appending(path: "rest/v1/account_state")
        self.publishableKey = publishableKey
        self.session = session
        self.accessToken = accessToken
    }

    public func all() async throws -> [AccountStateRow] {
        var components = URLComponents(url: tableURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "scope,key,value,updated_at")]
        return Self.decode(try await send(try await request(components.url!)))
    }

    public func save(_ rows: [AccountStateRow]) async throws {
        guard !rows.isEmpty else { return }
        var components = URLComponents(url: tableURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id,scope,key")]
        var request = try await request(components.url!, method: "POST")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try Self.body(rows)
        _ = try await send(request)
    }

    static func body(_ rows: [AccountStateRow]) throws -> Data {
        let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let objects: [[String: Any]] = try rows.map { row in
            ["scope": row.scope, "key": row.key, "value": try JSONSerialization.jsonObject(with: row.value, options: .fragmentsAllowed), "updated_at": row.updatedAt.formatted(style)]
        }
        return try JSONSerialization.data(withJSONObject: objects)
    }

    static func decode(_ data: Data) -> [AccountStateRow] {
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            guard let scope = row["scope"] as? String, let key = row["key"] as? String, let raw = row["value"],
                  let updated = (row["updated_at"] as? String).flatMap(date),
                  let value = try? JSONSerialization.data(withJSONObject: raw, options: .fragmentsAllowed) else { return nil }
            return AccountStateRow(scope: scope, key: key, value: value, updatedAt: updated)
        }
    }

    private static func date(_ text: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)) ?? (try? Date.ISO8601FormatStyle().parse(text))
    }

    private func request(_ url: URL, method: String = "GET") async throws -> URLRequest {
        guard let token = await accessToken() else { throw AccountStateServiceError.noSession }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let code = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["code"] as? String ?? ""
            if ["PGRST204", "PGRST205", "42P01", "42703"].contains(code) || (status == 404 && code.isEmpty) { throw AccountStateServiceError.notSetUp }
            throw AccountStateServiceError.failed(status: status)
        }
        return data
    }
}
