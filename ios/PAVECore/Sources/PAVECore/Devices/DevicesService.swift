import Foundation
import OSLog

/// Where the account is signed in, and signing other devices out.
public protocol DevicesService: Sendable {
    func devices() async throws -> [SignedInDevice]
    func signOut(_ device: SignedInDevice) async throws
    func signOutOtherDevices() async throws
}

public enum DevicesError: Error, Equatable, Sendable {
    case notSignedIn
    case notAllowed
    case noConnection
    /// The database functions of migration 20261112150000 are not there yet.
    case notSetUp
    case unavailable

    public init(_ error: any Error) { self = (error as? DevicesError) ?? .unavailable }
}

/// Reads the sessions through `my_sessions` and ends one through `end_my_session` (migration 20261112150000). Signing
/// every other device out uses the sign-out of Supabase Auth itself, which needs no migration.
public struct SupabaseDevicesService: DevicesService {
    static let logger = Logger(subsystem: "nl.fontys.pave", category: "devices")

    private let restURL: URL
    private let authURL: URL
    private let publishableKey: String
    private let session: URLSession
    private let accessToken: @Sendable () async -> String?

    public init(
        projectURL: URL,
        publishableKey: String,
        session: URLSession = .shared,
        accessToken: @escaping @Sendable () async -> String?
    ) {
        restURL = projectURL.appending(path: "rest/v1")
        authURL = projectURL.appending(path: "auth/v1")
        self.publishableKey = publishableKey
        self.session = session
        self.accessToken = accessToken
    }

    public func devices() async throws -> [SignedInDevice] {
        let data = try await send(try await request(restURL.appending(path: "rpc/my_sessions"), json: [:]))
        guard let rows = try? JSONDecoder().decode([SessionRow].self, from: data) else { throw DevicesError.unavailable }
        return rows.compactMap(\.device)
    }

    public func signOut(_ device: SignedInDevice) async throws {
        _ = try await send(try await request(restURL.appending(path: "rpc/end_my_session"), json: ["target": device.id]))
    }

    public func signOutOtherDevices() async throws {
        var components = URLComponents(url: authURL.appending(path: "logout"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "scope", value: "others")]
        guard let url = components?.url else { throw DevicesError.unavailable }
        _ = try await send(try await request(url, json: nil), accepting: [200, 204])
    }

    private func request(_ url: URL, json: [String: Any]?) async throws -> URLRequest {
        guard let token = await accessToken() else { throw DevicesError.notSignedIn }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 20
        urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let json {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        return urlRequest
    }

    private func send(_ urlRequest: URLRequest, accepting statuses: Set<Int> = [200]) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is URLError {
            throw DevicesError.noConnection
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if statuses.contains(status) { return data }
        throw Self.error(status: status, body: data)
    }

    static func error(status: Int, body: Data) -> DevicesError {
        let code = (try? JSONDecoder().decode(ErrorBody.self, from: body))?.code
        logger.error("Devices request failed: \(status, privacy: .public) \(code ?? "-", privacy: .public)")
        // PGRST202: the function does not exist (yet); 42883 is the same from Postgres itself.
        if code == "PGRST202" || code == "42883" { return .notSetUp }
        switch status {
        case 401: return .notSignedIn
        case 403: return .notAllowed
        default: return code == "42501" ? .notAllowed : .unavailable
        }
    }
}

private struct ErrorBody: Decodable {
    let code: String?
}

struct SessionRow: Decodable {
    let id: String
    let signed_in_at: String
    let last_active_at: String
    let user_agent: String?
    let is_current: Bool?

    var device: SignedInDevice? {
        let parse = Date.ISO8601FormatStyle()
        guard let signedIn = try? parse.parse(signed_in_at), let lastActive = try? parse.parse(last_active_at) else { return nil }
        return SignedInDevice(id: id, userAgent: user_agent, signedInAt: signedIn, lastActiveAt: lastActive, isCurrent: is_current ?? false)
    }
}
