import Foundation

public protocol AylaService: Sendable {
    func send(_ request: AylaRequest) async throws -> AylaReply
}

public enum AylaError: Error, Equatable, Sendable {
    case notSignedIn
    case insufficientAssurance
    case conversationNotFound
    case noConnection
    case unavailable
}

/// Talks to the `ayla` Supabase Edge Function with the session of the signed-in user.
public struct SupabaseAylaService: AylaService {
    private let endpoint: URL
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
}
