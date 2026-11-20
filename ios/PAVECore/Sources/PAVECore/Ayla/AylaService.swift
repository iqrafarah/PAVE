import Foundation

/// What comes in while Ayla writes her answer.
public enum AylaStreamEvent: Equatable, Sendable {
    /// The conversation the answer belongs to, before anything is written (also when you stop early).
    case started(conversationID: String)
    /// Everything she wrote so far.
    case text(String)
    /// The whole answer, with its cards and suggestions.
    case reply(AylaReply)
}

public protocol AylaService: Sendable {
    func send(_ request: AylaRequest) async throws -> AylaReply
    /// The answer while it is written. Cancelling the stream stops Ayla; what she wrote so far is kept.
    func stream(_ request: AylaRequest) -> AsyncThrowingStream<AylaStreamEvent, any Error>
    /// The user's most recent conversations, at most `limit`, and whether they can be pinned.
    func conversations(limit: Int) async throws -> AylaConversationList
    func messages(in conversationID: String) async throws -> [AylaStoredMessage]
    func setPinned(_ isPinned: Bool, conversationID: String) async throws
    /// Archive: out of the list and no longer pinned, kept until it is put back or deleted.
    func setArchived(_ isArchived: Bool, conversationID: String) async throws
    func setExpiry(_ expiry: AylaConversation.Expiry, conversationID: String) async throws
    /// Deletes the chats whose time is up, for good. Returns how many went.
    func expireChats() async throws -> Int
    /// "Projecten" (migration 20261118120000): make, change, pin and delete; deleting keeps the chats.
    /// `withLook`: send the icon and colour too, once projects have them (migration 20261119150000).
    func createProject(name: String, instructions: String, icon: VaultFolderIcon?, color: VaultFolderColor?, withLook: Bool) async throws -> AylaProject
    func updateProject(_ project: AylaProject, withLook: Bool) async throws
    func setProjectPinned(_ isPinned: Bool, projectID: String) async throws
    func deleteProject(id: String) async throws
    /// "Bronnen" (migration 20261119160000): vault items Ayla uses in every chat of the project, newest first.
    /// `notSetUp` until the table exists.
    func projectSources(projectID: String) async throws -> [String]
    func addProjectSources(_ itemIDs: [String], projectID: String) async throws
    /// Only the link goes; the item stays in the vault.
    func removeProjectSource(_ itemID: String, projectID: String) async throws
    /// Puts a chat in a project, or takes it out with nil.
    func move(conversationID: String, toProject projectID: String?) async throws
    /// "Chat vergrendelen" (migration 20261118130000). One PIN of four digits for every locked chat, checked only in the
    /// database.
    func setLocked(_ isLocked: Bool, conversationID: String) async throws
    func chatPinExists() async throws -> Bool
    func setChatPin(_ pin: String) async throws
    /// True for the right PIN; throws `AylaChatPinError.tooManyAttempts` during the wait after five wrong tries.
    func checkChatPin(_ pin: String) async throws -> Bool
    /// "Pincode wijzigen": the database checks the current PIN (with the same wait after five wrong tries) first.
    func changeChatPin(from pin: String, to newPin: String) async throws
    /// "Pincode vergeten" without losing chats: after a fresh two-step code the PIN is replaced and the locked chats stay.
    func recoverChatPin(_ newPin: String) async throws
    /// "Alles verwijderen en opnieuw beginnen": deletes every locked chat for good and removes the PIN.
    func resetChatPin() async throws
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
    func remember(_ text: String, categories: [AylaMemory.Category], source: AylaMemory.Source, conversationID: String?) async throws -> AylaMemory
    func updateMemory(_ text: String, categories: [AylaMemory.Category], id: String) async throws
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

    /// Without streaming, the whole answer comes at once.
    public func stream(_ request: AylaRequest) -> AsyncThrowingStream<AylaStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.reply(try await send(request)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func rename(_ title: String, conversationID: String) async throws { throw AylaError.unavailable }
    public func setArchived(_ isArchived: Bool, conversationID: String) async throws { throw AylaError.notSetUp }
    public func setExpiry(_ expiry: AylaConversation.Expiry, conversationID: String) async throws { throw AylaError.notSetUp }
    public func expireChats() async throws -> Int { 0 }
    public func delete(conversationID: String) async throws { throw AylaError.unavailable }
    public func removeLastTurn(in conversationID: String) async throws { throw AylaError.unavailable }
    public func searchMessages(_ text: String) async throws -> [AylaSearchHit] { [] }
    public func createProject(name: String, instructions: String, icon: VaultFolderIcon?, color: VaultFolderColor?, withLook: Bool) async throws -> AylaProject { throw AylaError.notSetUp }
    public func updateProject(_ project: AylaProject, withLook: Bool) async throws { throw AylaError.notSetUp }
    public func setProjectPinned(_ isPinned: Bool, projectID: String) async throws { throw AylaError.notSetUp }
    public func deleteProject(id: String) async throws { throw AylaError.notSetUp }
    public func projectSources(projectID: String) async throws -> [String] { throw AylaError.notSetUp }
    public func addProjectSources(_ itemIDs: [String], projectID: String) async throws { throw AylaError.notSetUp }
    public func removeProjectSource(_ itemID: String, projectID: String) async throws { throw AylaError.notSetUp }
    public func move(conversationID: String, toProject projectID: String?) async throws { throw AylaError.notSetUp }
    public func setLocked(_ isLocked: Bool, conversationID: String) async throws { throw AylaError.notSetUp }
    public func chatPinExists() async throws -> Bool { throw AylaError.notSetUp }
    public func setChatPin(_ pin: String) async throws { throw AylaError.notSetUp }
    public func checkChatPin(_ pin: String) async throws -> Bool { throw AylaError.notSetUp }
    public func resetChatPin() async throws { throw AylaError.notSetUp }
    public func changeChatPin(from pin: String, to newPin: String) async throws { throw AylaError.notSetUp }
    public func recoverChatPin(_ newPin: String) async throws { throw AylaError.notSetUp }
    public func conversationChanges() -> AsyncStream<Void> { AsyncStream { $0.finish() } }

    /// Without a voice, the stream ends at once with `unavailable`, and the app falls back to the device voice.
    public func speech(for text: String) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { $0.finish(throwing: AylaError.unavailable) }
    }

    public func warmUp() async {}

    public func memories() async throws -> AylaMemories { throw AylaError.notSetUp }
    public func remember(
        _ text: String, categories: [AylaMemory.Category], source: AylaMemory.Source, conversationID: String?
    ) async throws -> AylaMemory {
        throw AylaError.notSetUp
    }
    public func updateMemory(_ text: String, categories: [AylaMemory.Category], id: String) async throws { throw AylaError.notSetUp }
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

    public func stream(_ request: AylaRequest) -> AsyncThrowingStream<AylaStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let token = await accessToken() else { throw AylaError.notSignedIn }
                    var urlRequest = URLRequest(url: endpoint, timeoutInterval: 60)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    urlRequest.httpBody = try AylaCoding.encoder.encode(request)

                    let (bytes, response): (URLSession.AsyncBytes, URLResponse)
                    do {
                        (bytes, response) = try await session.bytes(for: urlRequest)
                    } catch is URLError {
                        throw AylaError.noConnection
                    }
                    switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
                    case 200: break
                    case 401: throw AylaError.notSignedIn
                    case 403: throw AylaError.insufficientAssurance
                    case 404: throw AylaError.conversationNotFound
                    default: throw AylaError.unavailable
                    }

                    var event = ""
                    var finished = false
                    do {
                        for try await line in bytes.lines {
                            if line.hasPrefix("event:") {
                                event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                            } else if line.hasPrefix("data:"), let parsed = Self.streamEvent(event, data: Data(line.dropFirst(5).utf8)) {
                                switch parsed {
                                case .success(let streamEvent):
                                    continuation.yield(streamEvent)
                                    if case .reply = streamEvent { finished = true }
                                case .failure(let error):
                                    throw error
                                }
                            }
                        }
                    } catch is URLError {
                        throw AylaError.noConnection
                    }
                    guard finished else { throw AylaError.unavailable }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// One server-sent event of the Ayla function: `start`, `text`, `reply` or `error`.
    static func streamEvent(_ name: String, data: Data) -> Result<AylaStreamEvent, AylaError>? {
        struct Start: Decodable { let conversationId: String }
        struct Text: Decodable { let text: String }
        switch name {
        case "start":
            return (try? JSONDecoder().decode(Start.self, from: data)).map { .success(.started(conversationID: $0.conversationId)) }
        case "text":
            return (try? JSONDecoder().decode(Text.self, from: data)).map { .success(.text($0.text)) }
        case "reply":
            return .some((try? AylaReply.decode(data)).map { .success(.reply($0)) } ?? .failure(.unavailable))
        case "error":
            return .failure(.unavailable)
        default:
            return nil
        }
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
        let token = await accessToken()
        async let rowsRequest: [ConversationRow] = select(
            "ayla_conversations",
            query: [("select", "*"), ("order", "updated_at.desc"), ("limit", String(limit))],
            token: token
        )
        // Before their migrations there are no projects or locked chats: the list simply has none.
        async let projectsRequest: [ProjectRow]? = try? select("ayla_projects", query: [("select", "*"), ("order", "updated_at.desc")], token: token)
        async let lockedRequest: [LockedRow]? = try? select("ayla_locked_chats", query: [("select", "conversation_id")], token: token)
        // The archive in full, also chats older than the most recent ones; none before its migration.
        async let archivedRequest: [ConversationRow]? = try? select(
            "ayla_conversations", query: [("select", "*"), ("archived_at", "not.is.null"), ("order", "archived_at.desc")], token: token
        )
        let (recentRows, projectRows, lockedRows, archivedRows) = try await (rowsRequest, projectsRequest, lockedRequest, archivedRequest)
        let recentIDs = Set(recentRows.map(\.id))
        let rows = recentRows + (archivedRows ?? []).filter { !recentIDs.contains($0.id) }
        let locked = Set((lockedRows ?? []).map(\.conversationID))
        var list = AylaConversationList(
            conversations: rows.map {
                AylaConversation(
                    id: $0.id,
                    title: $0.title,
                    updatedAt: Self.date(from: $0.updatedAt),
                    pinnedAt: $0.pinnedAt.map(Self.date(from:)),
                    startedOn: $0.startedOn.flatMap(AylaDevice.init(rawValue:)),
                    projectID: $0.projectID,
                    isLocked: locked.contains($0.id),
                    createdAt: $0.createdAt.map(Self.date(from:)),
                    archivedAt: $0.archivedAt.map(Self.date(from:)),
                    expiry: AylaConversation.Expiry(days: $0.expiryDays)
                )
            },
            canPin: rows.contains(where: \.hasPinColumn),
            projects: (projectRows ?? []).map(\.project),
            canUseProjects: projectRows != nil,
            canLock: lockedRows != nil,
            canArchive: rows.contains(where: \.hasArchiveColumn)
        )
        // Without any project yet, a request for the column itself says whether it exists.
        if let projectRows, projectRows.isEmpty {
            let probe: [IDRow]? = try? await select("ayla_projects", query: [("select", "id,icon,color"), ("limit", "0")], token: token)
            list.canStyleProjects = probe != nil
        } else {
            list.canStyleProjects = (projectRows ?? []).contains(where: \.hasLook)
        }
        return list
    }

    // MARK: Projects

    public func createProject(name: String, instructions: String, icon: VaultFolderIcon?, color: VaultFolderColor?, withLook: Bool) async throws -> AylaProject {
        guard let name = AylaProject.cleanName(name) else { throw AylaError.unavailable }
        var body: [String: String?] = ["name": name, "instructions": String(instructions.prefix(AylaProject.maxInstructionsLength))]
        if withLook {
            body["icon"] = icon?.rawValue
            body["color"] = color?.rawValue
        }
        let urlRequest = try await authorized(
            "ayla_projects", query: [("select", "*")], method: "POST", body: try JSONEncoder().encode(body), returning: true
        )
        let data = try await perform(urlRequest, accepting: [201])
        guard let row = try? AylaCoding.decoder.decode([ProjectRow].self, from: data).first else { throw AylaError.unavailable }
        return row.project
    }

    public func updateProject(_ project: AylaProject, withLook: Bool) async throws {
        guard let name = AylaProject.cleanName(project.name) else { throw AylaError.unavailable }
        var body: [String: String?] = [
            "name": name,
            "instructions": String(project.instructions.prefix(AylaProject.maxInstructionsLength)),
            "updated_at": Date.now.ISO8601Format(),
        ]
        if withLook {
            body["icon"] = project.icon?.rawValue
            body["color"] = project.color?.rawValue
        }
        let urlRequest = try await authorized(
            "ayla_projects", query: [("id", "eq.\(project.id)"), ("select", "id")], method: "PATCH",
            body: try JSONEncoder().encode(body), returning: true
        )
        try await expectRow(from: urlRequest)
    }

    public func projectSources(projectID: String) async throws -> [String] {
        let rows: [SourceRow] = try await select(
            "ayla_project_sources",
            query: [("select", "item_id"), ("project_id", "eq.\(projectID)"), ("order", "created_at.desc")]
        )
        return rows.map(\.itemID)
    }

    public func addProjectSources(_ itemIDs: [String], projectID: String) async throws {
        guard !itemIDs.isEmpty else { return }
        let body = itemIDs.map { ["project_id": projectID, "item_id": $0] }
        var urlRequest = try await authorized("ayla_project_sources", query: [], method: "POST", body: try JSONEncoder().encode(body))
        urlRequest.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        _ = try await perform(urlRequest, accepting: [200, 201, 204])
    }

    public func removeProjectSource(_ itemID: String, projectID: String) async throws {
        let urlRequest = try await authorized(
            "ayla_project_sources", query: [("project_id", "eq.\(projectID)"), ("item_id", "eq.\(itemID)")], method: "DELETE"
        )
        _ = try await perform(urlRequest, accepting: [200, 204])
    }

    public func setProjectPinned(_ isPinned: Bool, projectID: String) async throws {
        let body = ["pinned_at": isPinned ? Date.now.ISO8601Format() : nil]
        let urlRequest = try await authorized(
            "ayla_projects", query: [("id", "eq.\(projectID)")], method: "PATCH", body: try JSONEncoder().encode(body)
        )
        _ = try await perform(urlRequest, accepting: [200, 204])
    }

    public func deleteProject(id: String) async throws {
        let urlRequest = try await authorized(
            "ayla_projects", query: [("id", "eq.\(id)"), ("select", "id")], method: "DELETE", returning: true
        )
        try await expectRow(from: urlRequest)
    }

    public func move(conversationID: String, toProject projectID: String?) async throws {
        let body = ["project_id": projectID]
        let urlRequest = try await authorized(
            "ayla_conversations", query: [("id", "eq.\(conversationID)"), ("select", "id")], method: "PATCH",
            body: try JSONEncoder().encode(body), returning: true
        )
        try await expectRow(from: urlRequest)
    }

    // MARK: Locked chats

    public func setLocked(_ isLocked: Bool, conversationID: String) async throws {
        if isLocked {
            let urlRequest = try await authorized(
                "ayla_locked_chats", query: [], method: "POST", body: try JSONEncoder().encode(["conversation_id": conversationID])
            )
            _ = try await perform(urlRequest, accepting: [201, 204, 409])
        } else {
            let urlRequest = try await authorized(
                "ayla_locked_chats", query: [("conversation_id", "eq.\(conversationID)")], method: "DELETE"
            )
            _ = try await perform(urlRequest, accepting: [200, 204])
        }
    }

    public func chatPinExists() async throws -> Bool {
        let data = try await rpc("ayla_chat_pin_exists", body: [:])
        return (try? JSONDecoder().decode(Bool.self, from: data)) ?? false
    }

    public func setChatPin(_ pin: String) async throws {
        _ = try await rpc("ayla_set_chat_pin", body: ["pin": pin])
    }

    public func checkChatPin(_ pin: String) async throws -> Bool {
        let data = try await rpc("ayla_check_chat_pin", body: ["pin": pin])
        return (try? JSONDecoder().decode(Bool.self, from: data)) ?? false
    }

    public func resetChatPin() async throws {
        _ = try await rpc("ayla_reset_chat_pin", body: [:])
    }

    public func changeChatPin(from pin: String, to newPin: String) async throws {
        _ = try await rpc("ayla_change_chat_pin", body: ["pin": pin, "new_pin": newPin])
    }

    public func recoverChatPin(_ newPin: String) async throws {
        _ = try await rpc("ayla_recover_chat_pin", body: ["new_pin": newPin])
    }

    /// Calls a database function. Its own errors (`raise exception 'too_many_attempts'`) come back as their message.
    private func rpc(_ name: String, body: [String: String]) async throws -> Data {
        let urlRequest = try await authorized("rpc/\(name)", query: [], method: "POST", body: try JSONEncoder().encode(body), returning: true)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is URLError {
            throw AylaError.noConnection
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(status) { return data }
        switch (try? JSONDecoder().decode(PostgrestError.self, from: data))?.message {
        case "too_many_attempts": throw AylaChatPinError.tooManyAttempts
        case "no_pin": throw AylaChatPinError.noPin
        case "pin_exists": throw AylaChatPinError.alreadySet
        case "invalid_pin", "wrong_pin": throw AylaChatPinError.wrong
        case "recent_mfa_required": throw AylaChatPinError.needsRecentVerification
        case "mfa_required": throw AylaError.insufficientAssurance
        default: break
        }
        if Self.isMissingTable(status: status, body: data) || status == 404 { throw AylaError.notSetUp }
        if status == 401 { throw AylaError.notSignedIn }
        throw AylaError.unavailable
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

    public func setArchived(_ isArchived: Bool, conversationID: String) async throws {
        // An archived chat is no longer pinned, so it comes back as an ordinary chat.
        let body: [String: String?] = isArchived ? ["archived_at": Date.now.ISO8601Format(), "pinned_at": nil] : ["archived_at": nil]
        let urlRequest = try await authorized(
            "ayla_conversations", query: [("id", "eq.\(conversationID)"), ("select", "id")], method: "PATCH",
            body: try JSONEncoder().encode(body), returning: true
        )
        try await expectRow(from: urlRequest)
    }

    public func setExpiry(_ expiry: AylaConversation.Expiry, conversationID: String) async throws {
        let urlRequest = try await authorized(
            "ayla_conversations", query: [("id", "eq.\(conversationID)"), ("select", "id")], method: "PATCH",
            body: try JSONEncoder().encode(["expiry_days": expiry.storedDays]), returning: true
        )
        try await expectRow(from: urlRequest)
    }

    public func expireChats() async throws -> Int {
        let data = try await rpc("ayla_expire_my_chats", body: [:])
        return (try? JSONDecoder().decode(Int.self, from: data)) ?? 0
    }

    public func messages(in conversationID: String) async throws -> [AylaStoredMessage] {
        let rows: [MessageRow] = try await select(
            "ayla_messages",
            query: [("select", "id,role,text,reply,created_at"), ("conversation_id", "eq.\(conversationID)"), ("order", "created_at.asc")]
        )
        return rows.compactMap { row in
            guard let role = AylaStoredMessage.Role(rawValue: row.role) else { return nil }
            return AylaStoredMessage(
                id: row.id, role: role, text: row.text, reply: row.reply,
                sentAt: row.created_at.map(Self.date(from:)) ?? .distantPast,
                attachments: row.attachments
            )
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
        if Self.isMissingColumn(status: status, body: data) { throw MissingColumn() }
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

    /// PostgREST answers a column that does not exist with 400 and code PGRST204.
    static func isMissingColumn(status: Int, body: Data) -> Bool {
        guard status == 400, let error = try? JSONDecoder().decode(PostgrestError.self, from: body) else { return false }
        return error.code == "PGRST204"
    }

    // MARK: Memory

    /// `*` keeps working before the category column exists: those notes count as "Over jou".
    public func memories() async throws -> AylaMemories {
        async let settings: [SettingsRow] = select("ayla_settings", query: [("select", "memory_enabled")])
        async let rows: [MemoryRow] = select(
            "ayla_memories",
            query: [("select", "*"), ("order", "created_at.desc"), ("limit", "200")]
        )
        let (enabled, notes) = try await (settings.first?.memory_enabled ?? true, rows)
        return AylaMemories(isEnabled: enabled, notes: notes.map(\.memory))
    }

    public func remember(
        _ text: String, categories: [AylaMemory.Category], source: AylaMemory.Source, conversationID: String?
    ) async throws -> AylaMemory {
        guard let text = AylaMemory.clean(text) else { throw AylaError.unavailable }
        let categories = AylaMemory.tidy(categories)
        let body = MemoryBody(text: text, categories: categories, source: source.rawValue, conversationID: conversationID)
        let data = try await withoutMissingColumns(body) { body in
            let urlRequest = try await authorized(
                "ayla_memories",
                query: [("select", "*")],
                method: "POST",
                body: try JSONEncoder().encode(body),
                returning: true
            )
            return try await perform(urlRequest, accepting: [201])
        }
        guard let row = try? JSONDecoder().decode([MemoryRow].self, from: data).first else { throw AylaError.unavailable }
        return row.memory
    }

    public func updateMemory(_ text: String, categories: [AylaMemory.Category], id: String) async throws {
        guard let text = AylaMemory.clean(text) else { throw AylaError.unavailable }
        let body = MemoryBody(text: text, categories: AylaMemory.tidy(categories), updatedAt: Date.now.ISO8601Format())
        _ = try await withoutMissingColumns(body) { body in
            let urlRequest = try await authorized(
                "ayla_memories",
                query: [("id", "eq.\(id)"), ("select", "id")],
                method: "PATCH",
                body: try JSONEncoder().encode(body),
                returning: true
            )
            try await expectRow(from: urlRequest)
            return Data()
        }
    }

    /// Before a migration runs, Supabase refuses a column it does not know (PGRST204). Then the note is saved with less:
    /// first without the list of categories (20261110180000), then also without the main category (20261109160000).
    private func withoutMissingColumns(_ body: MemoryBody, _ send: (MemoryBody) async throws -> Data) async throws -> Data {
        var body = body
        while true {
            do {
                return try await send(body)
            } catch is MissingColumn {
                if body.categories != nil {
                    body.categories = nil
                } else if body.category != nil {
                    body.category = nil
                } else {
                    throw AylaError.unavailable
                }
            }
        }
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
    let projectID: String?
    let createdAt: String?
    let archivedAt: String?
    let expiryDays: Int?
    /// False while the `pinned_at` column has not been added yet.
    let hasPinColumn: Bool
    /// False before the migration with the archive and the expiry (20261120120000).
    let hasArchiveColumn: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case updatedAt = "updated_at"
        case pinnedAt = "pinned_at"
        case startedOn = "started_on"
        case projectID = "project_id"
        case createdAt = "created_at"
        case archivedAt = "archived_at"
        case expiryDays = "expiry_days"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        pinnedAt = try container.decodeIfPresent(String.self, forKey: .pinnedAt)
        startedOn = try container.decodeIfPresent(String.self, forKey: .startedOn)
        projectID = try container.decodeIfPresent(String.self, forKey: .projectID)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        archivedAt = try container.decodeIfPresent(String.self, forKey: .archivedAt)
        expiryDays = try container.decodeIfPresent(Int.self, forKey: .expiryDays)
        hasPinColumn = container.contains(.pinnedAt)
        hasArchiveColumn = container.contains(.archivedAt)
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

private struct MissingColumn: Error {}

private struct PostgrestError: Decodable {
    let code: String?
    var message: String?
}

private struct ProjectRow: Decodable {
    let id: String
    let name: String
    let instructions: String?
    let updated_at: String
    let pinned_at: String?
    let icon: String?
    let color: String?
    /// False before the migration with the icon and colour (20261119150000).
    let hasLook: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name, instructions, updated_at, pinned_at, icon, color
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
        updated_at = try container.decode(String.self, forKey: .updated_at)
        pinned_at = try container.decodeIfPresent(String.self, forKey: .pinned_at)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        hasLook = container.contains(.icon)
    }

    var project: AylaProject {
        AylaProject(
            id: id, name: name, instructions: instructions ?? "",
            updatedAt: SupabaseAylaService.date(from: updated_at), pinnedAt: pinned_at.map(SupabaseAylaService.date(from:)),
            icon: icon.flatMap(VaultFolderIcon.init(rawValue:)), color: color.flatMap(VaultFolderColor.init(rawValue:))
        )
    }
}

private struct SourceRow: Decodable {
    let itemID: String

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
    }
}

private struct LockedRow: Decodable {
    let conversationID: String

    private enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
    }
}

private struct SettingsRow: Decodable {
    let memory_enabled: Bool
}

struct MemoryRow: Decodable {
    let id: String
    let text: String
    let source: String
    let category: String?
    /// Missing before 20261110180000_ayla_memory_more_categories.sql runs.
    let categories: [String]?
    let created_at: String

    var memory: AylaMemory {
        let all = (categories ?? []).map { AylaMemory.Category(code: $0) }
        return AylaMemory(
            id: id,
            text: text,
            categories: all.isEmpty ? [AylaMemory.Category(code: category)] : all,
            source: AylaMemory.Source(rawValue: source) ?? .ayla,
            createdAt: SupabaseAylaService.date(from: created_at)
        )
    }
}

/// A note as it is sent. The main category is the first of `categories`; both go along, so the Ayla function and the
/// web, which read only `category`, keep working.
struct MemoryBody: Encodable {
    var text: String
    var category: String?
    var categories: [String]?
    var source: String?
    var conversationID: String?
    var updatedAt: String?

    init(text: String, categories: [AylaMemory.Category], source: String? = nil, conversationID: String? = nil, updatedAt: String? = nil) {
        self.text = text
        category = categories.first?.rawValue
        self.categories = categories.map(\.rawValue)
        self.source = source
        self.conversationID = conversationID
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case text, category, categories, source
        case conversationID = "conversation_id"
        case updatedAt = "updated_at"
    }
}

private struct TurnRow: Decodable {
    let id: String
    let role: String
}

/// `reply` holds Ayla's whole reply on her messages and only the attachment names on the user's; a reply this version
/// cannot read is left out rather than losing the conversation.
private struct MessageRow: Decodable {
    let id: String
    let role: String
    let text: String
    let reply: AylaReply?
    let attachments: [String]
    let created_at: String?

    private enum CodingKeys: String, CodingKey { case id, role, text, reply, created_at }
    private struct AttachmentNames: Decodable { let attachments: [String] }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        role = try container.decode(String.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        reply = try? container.decodeIfPresent(AylaReply.self, forKey: .reply)
        attachments = (try? container.decodeIfPresent(AttachmentNames.self, forKey: .reply))?.attachments ?? []
    }
}

private struct ProfileRow: Decodable {
    let preferred_name: String?
    let full_name: String?
}
