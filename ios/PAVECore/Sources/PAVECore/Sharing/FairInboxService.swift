import Foundation

/// The employer's inbox in the demo, through the public function `fair-inbox`: whoever has the employer's secret key
/// sees who applied and can invite them. No account: in the demo a classmate plays the recruiter.
public struct FairInboxService: Sendable {
    private let functionURL: URL
    private let publishableKey: String
    private let session: URLSession

    public init(projectURL: URL, publishableKey: String, session: URLSession = .shared) {
        functionURL = projectURL.appending(path: "functions/v1/fair-inbox")
        self.publishableKey = publishableKey
        self.session = session
    }

    public func inbox(slug: String, key: String) async throws -> EmployerInbox {
        try await call(["slug": slug, "key": key, "action": "list"])
    }

    public func invite(_ applicationID: String, at moment: Date, message: String, slug: String, key: String) async throws -> EmployerInbox {
        try await call([
            "slug": slug, "key": key, "action": "invite", "applicationID": applicationID,
            "moment": moment.formatted(.iso8601), "message": message,
        ])
    }

    private func call(_ body: [String: String]) async throws -> EmployerInbox {
        var request = URLRequest(url: functionURL, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch is URLError {
            throw ShareError.noConnection
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: return try Self.inbox(from: data)
        case 403: throw ShareError.notSignedIn
        default: throw ShareError.unavailable
        }
    }

    static func inbox(from data: Data) throws -> EmployerInbox {
        struct Answer: Decodable {
            struct Employer: Decodable { let name: String; let stand: String? }
            let employer: Employer?
            let applications: [InboxApplication]
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) ?? Date.ISO8601FormatStyle().parse(text) { return date }
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text.replacingOccurrences(of: " ", with: "T").replacingOccurrences(of: "+00", with: "+00:00")) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "date")
        }
        guard let answer = try? decoder.decode(Answer.self, from: data) else { throw ShareError.unavailable }
        return EmployerInbox(name: answer.employer?.name ?? "", stand: answer.employer?.stand, applications: answer.applications)
    }
}
