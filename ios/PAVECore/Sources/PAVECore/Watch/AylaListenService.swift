import Foundation

/// Turns what you said into text. The Watch has no speech recognition of its own, so the recording goes to the
/// `ayla-listen` function; only the text comes back and the recording is not kept.
public protocol AylaListenService: Sendable {
    /// The words in `audio` (16-bit WAV); empty when nothing could be understood.
    func transcribe(_ audio: Data) async throws -> String
}

public struct SupabaseAylaListenService: AylaListenService {
    /// About 30 seconds of 16 kHz mono WAV; the function refuses more.
    public static let maximumBytes = 1_000_000

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
        endpoint = projectURL.appending(path: "functions/v1/ayla-listen")
        self.publishableKey = publishableKey
        self.session = session
        self.accessToken = accessToken
    }

    public func transcribe(_ audio: Data) async throws -> String {
        guard !audio.isEmpty, audio.count <= Self.maximumBytes else { throw AylaError.unavailable }
        guard let token = await accessToken() else { throw AylaError.notSignedIn }
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = audio

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is URLError {
            throw AylaError.noConnection
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200:
            guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { throw AylaError.unavailable }
            return reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
        case 401: throw AylaError.notSignedIn
        case 403: throw AylaError.insufficientAssurance
        case 404: throw AylaError.notSetUp
        default: throw AylaError.unavailable
        }
    }

    private struct Reply: Decodable {
        let text: String
    }
}
