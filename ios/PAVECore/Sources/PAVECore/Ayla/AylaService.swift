import Foundation

public protocol AylaService: Sendable {
    func send(_ request: AylaRequest) async throws -> AylaReply
    /// The user's most recent conversations, at most `limit`, and whether they can be pinned.
    func conversations(limit: Int) async throws -> AylaConversationList
    func messages(in conversationID: String) async throws -> [AylaStoredMessage]
    func setPinned(_ isPinned: Bool, conversationID: String) async throws
    func rename(_ title: String, conversationID: String) async throws
    /// Removes the conversation and its messages for good.
    func delete(conversationID: String) async throws
    /// Removes the last question and Ayla's answer to it, so the question can be asked again or changed.
    func removeLastTurn(in conversationID: String) async throws
    /// Messages in the user's conversations that contain `text`, the most recent first.
    func searchMessages(_ text: String) async throws -> [AylaSearchHit]
    /// Fires whenever the user's conversations change on the server, also from the web or the Watch.
    func conversationChanges() -> AsyncStream<Void>
    /// The name Ayla uses to greet the user, from the profile.
    func firstName() async -> String?
    /// Ayla's voice reading `text` out loud: raw pcm16 audio (24 kHz, mono), piece by piece as it arrives.
    func speech(for text: String) -> AsyncThrowingStream<Data, any Error>
    /// Wakes Ayla up on the server, so the first spoken answer does not wait for her to start.
    func warmUp() async
    /// What Ayla remembers about the user, the newest first. `notSetUp` until the tables exist.
    func memories() async throws -> AylaMemories
    /// Saves a note the user kept or wrote.
    func remember(_ text: String, source: AylaMemory.Source, conversationID: String?) async throws -> AylaMemory
    func updateMemory(_ text: String, id: String) async throws
    func forgetMemory(id: String) async throws
    func forgetAllMemories() async throws
    func setMemoryEnabled(_ isEnabled: Bool) async throws
}

extension AylaService {
    /// How many conversations the list loads at a time.
    public static var conversationPage: Int { 50 }

    public func conversations() async throws -> AylaConversationList {
        try await conversations(limit: Self.conversationPage)
    }

    public func rename(_ title: String, conversationID: String) async throws { throw AylaError.unavailable }
    public func delete(conversationID: String) async throws { throw AylaError.unavailable }
    public func removeLastTurn(in conversationID: String) async throws { throw AylaError.unavailable }
    public func searchMessages(_ text: String) async throws -> [AylaSearchHit] { [] }
    public func conversationChanges() -> AsyncStream<Void> { AsyncStream { $0.finish() } }

    /// Without a voice, the stream ends at once with `unavailable`, and the app falls back to the device voice.
    public func speech(for text: String) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { $0.finish(throwing: AylaError.unavailable) }
    }

    public func warmUp() async {}

    public func memories() async throws -> AylaMemories { throw AylaError.notSetUp }
    public func remember(_ text: String, source: AylaMemory.Source, conversationID: String?) async throws -> AylaMemory {
        throw AylaError.notSetUp
    }
    public func updateMemory(_ text: String, id: String) async throws { throw AylaError.notSetUp }
    public func forgetMemory(id: String) async throws { throw AylaError.notSetUp }
    public func forgetAllMemories() async throws { throw AylaError.notSetUp }
    public func setMemoryEnabled(_ isEnabled: Bool) async throws { throw AylaError.notSetUp }
}

public enum AylaError: Error, Equatable, Sendable {
    case notSignedIn
    case insufficientAssurance
    case conversationNotFound
    case noConnection
    case unavailable
    /// This part is not in the database yet (the migration has not run).
    case notSetUp

    public init(_ error: any Error) { self = (error as? AylaError) ?? .unavailable }
}

/// Talks to the `ayla` Supabase Edge Function with the session of the signed-in user.
public struct SupabaseAylaService: AylaService {
    private let endpoint: URL
    private let voiceEndpoint: URL
    private let restURL: URL
    private let projectURL: URL
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
        voiceEndpoint = projectURL.appending(path: "functions/v1/ayla-voice")
        restURL = projectURL.appending(path: "rest/v1")
        self.projectURL = projectURL
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

    /// Reads every column, so the list still loads before the `pinned_at` column exists.
    /// 0.1 s of audio per piece, so playback can start right away without thousands of tiny pieces.
    static let speechPieceSize = 4800

    /// A server function that has not run for a while first has to start, which can take seconds. A preflight
    /// request starts both functions without asking Ayla anything, so it costs nothing.
    public func warmUp() async {
        guard let token = await accessToken() else { return }
        await withTaskGroup(of: Void.self) { group in
            for url in [endpoint, voiceEndpoint] {
                var urlRequest = URLRequest(url: url, timeoutInterval: 15)
                urlRequest.httpMethod = "OPTIONS"
                urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let session = session
                group.addTask { _ = try? await session.data(for: urlRequest) }
            }
        }
    }

    public func speech(for text: String) -> AsyncThrowingStream<Data, any Error> {
        let endpoint = voiceEndpoint
        let publishableKey = publishableKey
        let session = session
        let accessToken = accessToken
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let token = await accessToken() else { throw AylaError.notSignedIn }
                    var urlRequest = URLRequest(url: endpoint, timeoutInterval: 60)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    urlRequest.httpBody = try JSONEncoder().encode(["text": text])

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
                    case 200: break
                    case 401: throw AylaError.notSignedIn
                    case 403: throw AylaError.insufficientAssurance
                    default: throw AylaError.unavailable
                    }
                    var piece = Data()
                    piece.reserveCapacity(Self.speechPieceSize)
                    for try await byte in bytes {
                        piece.append(byte)
                        if piece.count >= Self.speechPieceSize {
                            continuation.yield(piece)
                            piece.removeAll(keepingCapacity: true)
                        }
                    }
                    if !piece.isEmpty { continuation.yield(piece) }
                    continuation.finish()
                } catch is URLError {
                    continuation.finish(throwing: AylaError.noConnection)
                } catch {
                    continuation.finish(throwing: AylaError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func conversations(limit: Int) async throws -> AylaConversationList {
        let rows: [ConversationRow] = try await select(
            "ayla_conversations",
            query: [("select", "*"), ("order", "updated_at.desc"), ("limit", String(limit))]
        )
        return AylaConversationList(
            conversations: rows.map {
                AylaConversation(
                    id: $0.id,
                    title: $0.title,
                    updatedAt: Self.date(from: $0.updatedAt),
                    pinnedAt: $0.pinnedAt.map(Self.date(from:)),
                    startedOn: $0.startedOn.flatMap(AylaDevice.init(rawValue:))
                )
            },
            canPin: rows.contains(where: \.hasPinColumn)
        )
    }

    public func rename(_ title: String, conversationID: String) async throws {
        guard let title = AylaConversation.cleanTitle(title) else { throw AylaError.unavailable }
        let urlRequest = try await authorized(
            "ayla_conversations",
            query: [("id", "eq.\(conversationID)"), ("select", "id")],
            method: "PATCH",
            body: try JSONEncoder().encode(["title": title]),
            returning: true
        )
        try await expectRow(from: urlRequest)
    }

    /// The messages go with it (`on delete cascade`); the policy "Own conversations" only allows the user's own.
    public func delete(conversationID: String) async throws {
        let urlRequest = try await authorized(
            "ayla_conversations",
            query: [("id", "eq.\(conversationID)"), ("select", "id")],
            method: "DELETE",
            returning: true
        )
        try await expectRow(from: urlRequest)
    }

    /// The server saves a question and its answer together, so they are the two newest messages. Only when that is
    /// really so are they removed; the policy "Delete own messages" only allows the user's own.
    public func removeLastTurn(in conversationID: String) async throws {
        let rows: [TurnRow] = try await select(
            "ayla_messages",
            query: [
                ("select", "id,role"), ("conversation_id", "eq.\(conversationID)"),
                ("order", "created_at.desc"), ("limit", "2"),
            ]
        )
        guard Set(rows.map(\.role)) == ["user", "ayla"] else { throw AylaError.conversationNotFound }
        let urlRequest = try await authorized(
            "ayla_messages",
            query: [("id", "in.(\(rows.map(\.id).joined(separator: ",")))"), ("select", "id")],
            method: "DELETE",
            returning: true
        )
        let data = try await perform(urlRequest, accepting: [200])
        guard let deleted = try? JSONDecoder().decode([IDRow].self, from: data), deleted.count == 2 else {
            throw AylaError.unavailable
        }
    }

    /// Supabase answers "done" also when a security rule let nothing through; asking for the changed row back shows
    /// whether something really changed.
    private func expectRow(from urlRequest: URLRequest) async throws {
        let data = try await perform(urlRequest, accepting: [200])
        guard let rows = try? JSONDecoder().decode([IDRow].self, from: data) else { throw AylaError.unavailable }
        guard !rows.isEmpty else { throw AylaError.conversationNotFound }
    }

    public func conversationChanges() -> AsyncStream<Void> {
        let socket = AylaRealtime.socketURL(projectURL: projectURL, publishableKey: publishableKey)
        let session = session
        let accessToken = accessToken
        return AsyncStream { continuation in
            let task = Task {
                var wait = 1.0
                while !Task.isCancelled {
                    let joined = await AylaRealtime.listen(socket: socket, session: session, accessToken: accessToken) {
                        continuation.yield()
                    }
                    if joined { wait = 1 }
                    try? await Task.sleep(for: .seconds(wait))
                    wait = min(30, wait * 2)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func searchMessages(_ text: String) async throws -> [AylaSearchHit] {
        // PostgREST reads `*` as the wildcard and commas and brackets as syntax, so those are left out.
        let words = text.filter { !"*,()%\\".contains($0) }.trimmingCharacters(in: .whitespaces)
        guard words.count >= 2 else { return [] }
        let rows: [SearchRow] = try await select(
            "ayla_messages",
            query: [
                ("select", "id,conversation_id,text"),
                ("text", "ilike.*\(words)*"),
                ("order", "created_at.desc"),
                ("limit", "30"),
            ]
        )
        return rows.map { AylaSearchHit(id: $0.id, conversationID: $0.conversationID, snippet: AylaSearchHit.snippet(of: $0.text, around: words)) }
    }

    public func setPinned(_ isPinned: Bool, conversationID: String) async throws {
        let body = ["pinned_at": isPinned ? Date.now.ISO8601Format() : nil]
        let urlRequest = try await authorized(
            "ayla_conversations",
            query: [("id", "eq.\(conversationID)")],
            method: "PATCH",
            body: try JSONEncoder().encode(body)
        )
        _ = try await perform(urlRequest, accepting: [200, 204])
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
        let urlRequest = try await authorized(table, query: query, token: token)
        let data = try await perform(urlRequest, accepting: [200])
        guard let rows = try? AylaCoding.decoder.decode([Row].self, from: data) else { throw AylaError.unavailable }
        return rows
    }

    private func authorized(
        _ table: String,
        query: [(String, String)],
        method: String = "GET",
        body: Data? = nil,
        token: String? = nil,
        returning: Bool = false
    ) async throws -> URLRequest {
        var token = token
        if token == nil { token = await accessToken() }
        guard let token else { throw AylaError.notSignedIn }
        var components = URLComponents(url: restURL.appending(path: table), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        var urlRequest = URLRequest(url: components.url!, timeoutInterval: 30)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body
        urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if returning {
            urlRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        } else if body != nil {
            urlRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        }
        return urlRequest
    }

    private func perform(_ urlRequest: URLRequest, accepting statuses: Set<Int>) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is URLError {
            throw AylaError.noConnection
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if statuses.contains(status) { return data }
        if Self.isMissingTable(status: status, body: data) { throw AylaError.notSetUp }
        switch status {
        case 401: throw AylaError.notSignedIn
        case 403: throw AylaError.insufficientAssurance
        default: throw AylaError.unavailable
        }
    }

    /// PostgREST answers a table that does not exist with 404 and code PGRST205.
    static func isMissingTable(status: Int, body: Data) -> Bool {
        guard status == 404 || status == 400,
              let error = try? JSONDecoder().decode(PostgrestError.self, from: body)
        else { return false }
        return error.code == "PGRST205" || error.code == "42P01"
    }

    // MARK: Memory

    public func memories() async throws -> AylaMemories {
        async let settings: [SettingsRow] = select("ayla_settings", query: [("select", "memory_enabled")])
        async let rows: [MemoryRow] = select(
            "ayla_memories",
            query: [("select", "id,text,source,created_at"), ("order", "created_at.desc"), ("limit", "200")]
        )
        let (enabled, notes) = try await (settings.first?.memory_enabled ?? true, rows)
        return AylaMemories(isEnabled: enabled, notes: notes.map(\.memory))
    }

    public func remember(_ text: String, source: AylaMemory.Source, conversationID: String?) async throws -> AylaMemory {
        guard let text = AylaMemory.clean(text) else { throw AylaError.unavailable }
        var body = ["text": text, "source": source.rawValue]
        if let conversationID { body["conversation_id"] = conversationID }
        let urlRequest = try await authorized(
            "ayla_memories",
            query: [("select", "id,text,source,created_at")],
            method: "POST",
            body: try JSONEncoder().encode(body),
            returning: true
        )
        let data = try await perform(urlRequest, accepting: [201])
        guard let row = try? JSONDecoder().decode([MemoryRow].self, from: data).first else { throw AylaError.unavailable }
        return row.memory
    }

    public func updateMemory(_ text: String, id: String) async throws {
        guard let text = AylaMemory.clean(text) else { throw AylaError.unavailable }
        let urlRequest = try await authorized(
            "ayla_memories",
            query: [("id", "eq.\(id)"), ("select", "id")],
            method: "PATCH",
            body: try JSONSerialization.data(withJSONObject: ["text": text, "updated_at": Date.now.ISO8601Format()]),
            returning: true
        )
        try await expectRow(from: urlRequest)
    }

    public func forgetMemory(id: String) async throws {
        let urlRequest = try await authorized(
            "ayla_memories",
            query: [("id", "eq.\(id)"), ("select", "id")],
            method: "DELETE",
            returning: true
        )
        try await expectRow(from: urlRequest)
    }

    /// PostgREST deletes nothing without a filter; the security rules keep it to the user's own notes.
    public func forgetAllMemories() async throws {
        let urlRequest = try await authorized("ayla_memories", query: [("id", "not.is.null")], method: "DELETE")
        _ = try await perform(urlRequest, accepting: [200, 204])
    }

    /// One row per user: written, or changed when it is already there.
    public func setMemoryEnabled(_ isEnabled: Bool) async throws {
        var urlRequest = try await authorized(
            "ayla_settings",
            query: [("on_conflict", "user_id")],
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: ["memory_enabled": isEnabled, "updated_at": Date.now.ISO8601Format()])
        )
        urlRequest.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        _ = try await perform(urlRequest, accepting: [200, 201, 204])
    }

    static func date(from text: String) -> Date {
        let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let plain = Date.ISO8601FormatStyle()
        return (try? withFraction.parse(text)) ?? (try? plain.parse(text)) ?? .distantPast
    }

    public static func subject(of token: String) -> String? {
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
    let updatedAt: String
    let pinnedAt: String?
    let startedOn: String?
    /// False while the `pinned_at` column has not been added yet.
    let hasPinColumn: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case updatedAt = "updated_at"
        case pinnedAt = "pinned_at"
        case startedOn = "started_on"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        pinnedAt = try container.decodeIfPresent(String.self, forKey: .pinnedAt)
        startedOn = try container.decodeIfPresent(String.self, forKey: .startedOn)
        hasPinColumn = container.contains(.pinnedAt)
    }
}

private struct IDRow: Decodable {
    let id: String
}

private struct SearchRow: Decodable {
    let id: String
    let conversationID: String
    let text: String

    private enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case text
    }
}

private struct PostgrestError: Decodable {
    let code: String?
}

private struct SettingsRow: Decodable {
    let memory_enabled: Bool
}

private struct MemoryRow: Decodable {
    let id: String
    let text: String
    let source: String
    let created_at: String

    var memory: AylaMemory {
        AylaMemory(
            id: id,
            text: text,
            source: AylaMemory.Source(rawValue: source) ?? .ayla,
            createdAt: SupabaseAylaService.date(from: created_at)
        )
    }
}

private struct TurnRow: Decodable {
    let id: String
    let role: String
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
