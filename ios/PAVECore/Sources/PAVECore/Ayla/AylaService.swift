import Foundation

public protocol AylaService: Sendable {
    func send(_ request: AylaRequest) async throws -> AylaReply
    /// The user's conversations, most recent first.
    func conversations() async throws -> [AylaConversation]
    func messages(in conversationID: String) async throws -> [AylaStoredMessage]
    /// The name Ayla uses to greet the user, from the profile.
    func firstName() async -> String?
}

public enum AylaError: Error, Equatable, Sendable {
    case notSignedIn
    case insufficientAssurance
    case conversationNotFound
    case noConnection
    case unavailable

    public init(_ error: any Error) { self = (error as? AylaError) ?? .unavailable }
}

/// Talks to the `ayla` Supabase Edge Function with the session of the signed-in user.
public struct SupabaseAylaService: AylaService {
    private let endpoint: URL
    private let restURL: URL
    private let publishableKey: String
    private let session: URLSession
    private let accessToken: @Sendable () async -> String?

    public init(
        projectURL: URL,
        publishableKey: String,
        session: URLSession = .shared,
        accessToken: @escaping @Sendable () async -> String?
    ) {
        endpoint = projectURL.appending(path: "functions/v1/ayla")
        restURL = projectURL.appending(path: "rest/v1")
        self.publishableKey = publishableKey
        self.session = session
        self.accessToken = accessToken
    }

    public func send(_ request: AylaRequest) async throws -> AylaReply {
        guard let token = await accessToken() else { throw AylaError.notSignedIn }

        var urlRequest = URLRequest(url: endpoint, timeoutInterval: 60)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try AylaCoding.encoder.encode(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is URLError {
            throw AylaError.noConnection
        }

        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200:
            do {
                return try AylaReply.decode(data)
            } catch {
                throw AylaError.unavailable
            }
        case 401:
            throw AylaError.notSignedIn
        case 403:
            throw AylaError.insufficientAssurance
        case 404:
            throw AylaError.conversationNotFound
        default:
            throw AylaError.unavailable
        }
    }

    public func conversations() async throws -> [AylaConversation] {
        let rows: [ConversationRow] = try await select(
            "ayla_conversations",
            query: [("select", "id,title,updated_at"), ("order", "updated_at.desc"), ("limit", "50")]
        )
        return rows.map { AylaConversation(id: $0.id, title: $0.title, updatedAt: Self.date(from: $0.updated_at)) }
    }

    public func messages(in conversationID: String) async throws -> [AylaStoredMessage] {
        let rows: [MessageRow] = try await select(
            "ayla_messages",
            query: [("select", "id,role,text,reply"), ("conversation_id", "eq.\(conversationID)"), ("order", "created_at.asc")]
        )
        return rows.compactMap { row in
            guard let role = AylaStoredMessage.Role(rawValue: row.role) else { return nil }
            return AylaStoredMessage(id: row.id, role: role, text: row.text, reply: row.reply)
        }
    }

    public func firstName() async -> String? {
        guard
            let token = await accessToken(),
            let userID = Self.subject(of: token),
            let rows: [ProfileRow] = try? await select(
                "profiles",
                query: [("select", "preferred_name,full_name"), ("id", "eq.\(userID)")],
                token: token
            ),
            let profile = rows.first
        else { return nil }
        if let preferred = profile.preferred_name?.trimmingCharacters(in: .whitespaces), !preferred.isEmpty {
            return preferred
        }
        return profile.full_name?.split(separator: " ").first.map(String.init)
    }

    private func select<Row: Decodable>(_ table: String, query: [(String, String)], token: String? = nil) async throws -> [Row] {
        var token = token
        if token == nil { token = await accessToken() }
        guard let token else { throw AylaError.notSignedIn }
        var components = URLComponents(url: restURL.appending(path: table), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        var urlRequest = URLRequest(url: components.url!, timeoutInterval: 30)
        urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is URLError {
            throw AylaError.noConnection
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200:
            guard let rows = try? AylaCoding.decoder.decode([Row].self, from: data) else { throw AylaError.unavailable }
            return rows
        case 401:
            throw AylaError.notSignedIn
        case 403:
            throw AylaError.insufficientAssurance
        default:
            throw AylaError.unavailable
        }
    }

    static func date(from text: String) -> Date {
        let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let plain = Date.ISO8601FormatStyle()
        return (try? withFraction.parse(text)) ?? (try? plain.parse(text)) ?? .distantPast
    }

    static func subject(of token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard
            let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["sub"] as? String
    }
}

private struct ConversationRow: Decodable {
    let id: String
    let title: String
    let updated_at: String
}

private struct MessageRow: Decodable {
    let id: String
    let role: String
    let text: String
    let reply: AylaReply?
}

private struct ProfileRow: Decodable {
    let preferred_name: String?
    let full_name: String?
}
