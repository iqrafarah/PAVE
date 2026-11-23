import Foundation

/// Turns what you said into text. The recording goes to the `ayla-listen` function (Voxtral, hosted by Mistral);
/// only the text comes back and the recording is not kept. The Watch has no speech recognition of its own; the iPhone
/// uses it for the question it sends, because it hears Dutch and names better than the recognizer on the device.
public protocol AylaListenService: Sendable {
    /// The words in `audio` (16-bit WAV); empty when nothing could be understood. `hints` are names the user may say,
    /// such as the companies and jobs on screen, so they are written the way PAVE writes them.
    func transcribe(_ audio: Data, hints: [String]) async throws -> String
}

extension AylaListenService {
    public func transcribe(_ audio: Data) async throws -> String {
        try await transcribe(audio, hints: [])
    }
}

public struct SupabaseAylaListenService: AylaListenService {
    /// About a minute of 16 kHz mono WAV; the function refuses more.
    public static let maximumBytes = 2_000_000
    /// What the function reads of the hints; the rest stays home.
    static let maximumHints = 40
    static let maximumHintLength = 80

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

    public func transcribe(_ audio: Data, hints: [String]) async throws -> String {
        guard !audio.isEmpty, audio.count <= Self.maximumBytes else { throw AylaError.unavailable }
        guard let token = await accessToken() else { throw AylaError.notSignedIn }
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let hints = Self.hintsHeader(hints) { request.setValue(hints, forHTTPHeaderField: "X-Ayla-Hints") }
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

    /// "Appwerk,Junior%20iOS-ontwikkelaar": each name percent-encoded, so a comma inside one never splits it.
    static func hintsHeader(_ hints: [String]) -> String? {
        var seen = Set<String>()
        let names = hints
            .map { $0.replacingOccurrences(of: ",", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= maximumHintLength && seen.insert($0.lowercased()).inserted }
            .prefix(maximumHints)
            .compactMap { $0.addingPercentEncoding(withAllowedCharacters: .alphanumerics) }
        return names.isEmpty ? nil : names.joined(separator: ",")
    }

    private struct Reply: Decodable {
        let text: String
    }
}
