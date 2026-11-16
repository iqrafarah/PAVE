import Foundation

/// Supabase Realtime for the user's conversations: a WebSocket that says when a row in `ayla_conversations` changes.
/// The policies still apply, so only the user's own changes come through.
public enum AylaRealtime {
    static func socketURL(projectURL: URL, publishableKey: String) -> URL {
        var components = URLComponents(url: projectURL.appending(path: "realtime/v1/websocket"), resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "http" ? "ws" : "wss"
        components.queryItems = [URLQueryItem(name: "apikey", value: publishableKey), URLQueryItem(name: "vsn", value: "1.0.0")]
        return components.url!
    }

    static func topic(for userID: String) -> String {
        "realtime:ayla-conversations-\(userID)"
    }

    static func joinMessage(userID: String, accessToken: String) -> String {
        let message: [String: Any] = [
            "topic": topic(for: userID),
            "event": "phx_join",
            "ref": "1",
            "join_ref": "1",
            "payload": [
                "config": [
                    "broadcast": ["self": false],
                    "presence": ["key": ""],
                    "postgres_changes": [
                        ["event": "*", "schema": "public", "table": "ayla_conversations", "filter": "user_id=eq.\(userID)"],
                    ],
                ],
                "access_token": accessToken,
            ],
        ]
        return json(message)
    }

    static func heartbeat(ref: Int) -> String {
        json(["topic": "phoenix", "event": "heartbeat", "payload": [String: Any](), "ref": String(ref)])
    }

    enum Event: Equatable {
        case joined
        case refused
        case change
        case other
    }

    static func event(in text: String) -> Event {
        guard
            let data = text.data(using: .utf8),
            let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let event = message["event"] as? String
        else { return .other }
        switch event {
        case "postgres_changes":
            return .change
        case "phx_reply":
            let status = (message["payload"] as? [String: Any])?["status"] as? String
            return status == "ok" ? .joined : .refused
        case "phx_error", "phx_close":
            return .refused
        default:
            return .other
        }
    }

    /// Listens until the connection ends. Returns whether it got as far as joining, so a broken connection is retried
    /// sooner than one that is refused.
    static func listen(
        socket: URL,
        session: URLSession,
        accessToken: @Sendable () async -> String?,
        onChange: @escaping @Sendable () -> Void
    ) async -> Bool {
        guard let token = await accessToken(), let userID = SupabaseAylaService.subject(of: token) else { return false }
        let webSocket = session.webSocketTask(with: socket)
        webSocket.resume()
        let heartbeat = Task {
            var ref = 2
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                try? await webSocket.send(.string(heartbeat(ref: ref)))
                ref += 1
            }
        }
        defer {
            heartbeat.cancel()
            webSocket.cancel(with: .goingAway, reason: nil)
        }
        var joined = false
        return await withTaskCancellationHandler {
            do {
                try await webSocket.send(.string(joinMessage(userID: userID, accessToken: token)))
                while !Task.isCancelled {
                    guard case .string(let text) = try await webSocket.receive() else { continue }
                    switch event(in: text) {
                    case .joined: joined = true
                    case .refused: return joined
                    case .change: onChange()
                    case .other: break
                    }
                }
            } catch {}
            return joined
        } onCancel: {
            webSocket.cancel(with: .goingAway, reason: nil)
        }
    }

    private static func json(_ object: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
