import Foundation

public enum ApplicationDraftServiceError: Error, Equatable, Sendable {
    /// The table does not exist yet (migration 20261126121000).
    case notSetUp
    case noSession
    case failed(status: Int)
}

/// Applications in Supabase (`application_drafts`, migration 20261126121000), with the user's own session, so row
/// level security decides what can be read and changed. The draft is kept whole, as the app writes it on the device.
public struct SupabaseApplicationDraftService: ApplicationDraftService {
    private let tableURL: URL
    private let publishableKey: String
    private let session: URLSession
    private let accessToken: @Sendable () async -> String?

    public init(projectURL: URL, publishableKey: String, session: URLSession = .shared, accessToken: @escaping @Sendable () async -> String?) {
        tableURL = projectURL.appending(path: "rest/v1/application_drafts")
        self.publishableKey = publishableKey
        self.session = session
        self.accessToken = accessToken
    }

    public func all() async throws -> [RemoteApplicationDraft] {
        var components = URLComponents(url: tableURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "id,draft,updated_at,deleted_at")]
        return try Self.decode(try await send(try await request(components.url!)))
    }

    public func save(_ draft: ApplicationDraft) async throws {
        try await upsert(Self.row(id: draft.id, draft: draft, updatedAt: draft.updatedAt, deletedAt: nil))
    }

    public func delete(id: String, at date: Date) async throws {
        try await upsert(Self.row(id: id, draft: nil, updatedAt: date, deletedAt: date))
    }

    // MARK: Rows

    static func row(id: String, draft: ApplicationDraft?, updatedAt: Date, deletedAt: Date?) throws -> Data {
        let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        var row: [String: Any] = ["id": id, "updated_at": updatedAt.formatted(style), "deleted_at": deletedAt.map { $0.formatted(style) } ?? NSNull()]
        row["draft"] = try draft.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) } ?? NSNull()
        return try JSONSerialization.data(withJSONObject: row)
    }

    /// A draft this version cannot read (written by a newer one) is left out, so it is neither overwritten nor shown.
    static func decode(_ data: Data) throws -> [RemoteApplicationDraft] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            guard let id = row["id"] as? String, let updatedAt = (row["updated_at"] as? String).flatMap(date) else { return nil }
            let deletedAt = (row["deleted_at"] as? String).flatMap(date)
            let draft = row["draft"].flatMap { value -> ApplicationDraft? in
                guard !(value is NSNull), let json = try? JSONSerialization.data(withJSONObject: value) else { return nil }
                return try? JSONDecoder().decode(ApplicationDraft.self, from: json)
            }
            guard draft != nil || deletedAt != nil else { return nil }
            return RemoteApplicationDraft(id: id, updatedAt: updatedAt, deletedAt: deletedAt, draft: draft)
        }
    }

    private static func date(_ text: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)) ?? (try? Date.ISO8601FormatStyle().parse(text))
    }

    // MARK: Requests

    private func upsert(_ body: Data) async throws {
        var components = URLComponents(url: tableURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id,id")]
        var request = try await request(components.url!, method: "POST")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = body
        _ = try await send(request)
    }

    private func request(_ url: URL, method: String = "GET") async throws -> URLRequest {
        guard let token = await accessToken() else { throw ApplicationDraftServiceError.noSession }
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
            if ["PGRST204", "PGRST205", "42P01", "42703"].contains(code) || (status == 404 && code.isEmpty) { throw ApplicationDraftServiceError.notSetUp }
            throw ApplicationDraftServiceError.failed(status: status)
        }
        return data
    }
}
