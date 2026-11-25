import Foundation

public enum ShareError: Error, Equatable, Sendable {
    case notSignedIn, noConnection, notSetUp, unavailable
}

/// Your shares in the account: making one, pausing, extending and taking it back, who looked, and the job fair.
public protocol ShareService: Sendable {
    /// Newest first, with their looks.
    func shares() async throws -> [ProfileShare]
    func create(_ draft: ShareDraft, now: Date) async throws -> ProfileShare
    /// Keeps a pdf with a share; returns its path in the bucket.
    func upload(pdf: Data, kind: String, shareID: String) async throws -> String
    func setDocuments(_ documents: [String: String], of share: ProfileShare) async throws
    func setPaused(_ isPaused: Bool, shareID: String) async throws
    func extend(shareID: String, until: Date) async throws
    /// For good: the database wipes what was kept with it; the files go too.
    func revoke(_ share: ProfileShare) async throws
    func employer(slug: String) async throws -> FairEmployer
    /// Your saved profiles, last changed first. `notSetUp` until migration 20261125160000 has run.
    func savedProfiles() async throws -> [SavedProfile]
    /// Makes it when it has no id yet, otherwise changes it; returns it as kept.
    func save(_ profile: SavedProfile) async throws -> SavedProfile
    func delete(profileID: String) async throws
}

extension ShareService {
    public func savedProfiles() async throws -> [SavedProfile] { throw ShareError.notSetUp }
    public func save(_ profile: SavedProfile) async throws -> SavedProfile { throw ShareError.notSetUp }
    public func delete(profileID: String) async throws { throw ShareError.notSetUp }
}

public final class SupabaseShareService: ShareService, @unchecked Sendable {
    public static let bucket = "profile-shares"

    private let restURL: URL
    private let storageURL: URL
    private let publishableKey: String
    private let session: URLSession
    private let accessToken: @Sendable () async -> String?

    public init(projectURL: URL, publishableKey: String, session: URLSession = .shared, accessToken: @escaping @Sendable () async -> String?) {
        restURL = projectURL.appending(path: "rest/v1")
        storageURL = projectURL.appending(path: "storage/v1")
        self.publishableKey = publishableKey
        self.session = session
        self.accessToken = accessToken
    }

    public func shares() async throws -> [ProfileShare] {
        let data = try await send(try await request(
            restURL.appending(path: "profile_shares"),
            query: [("select", "*,profile_share_views(id,viewed_at,action,viewer_name,viewer_organisation)"), ("order", "created_at.desc"), ("limit", "200")]
        ))
        guard let rows = try? Self.decoder.decode([ShareRow].self, from: data) else { throw ShareError.unavailable }
        return rows.map(\.share)
    }

    public func create(_ draft: ShareDraft, now: Date) async throws -> ProfileShare {
        let content = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft.content))
        let row: [String: Any] = [
            "title": draft.title.trimmingCharacters(in: .whitespaces),
            "recipient_name": draft.recipientName.trimmingCharacters(in: .whitespaces),
            "recipient_organisation": draft.recipientOrganisation.trimmingCharacters(in: .whitespaces).isEmpty ? NSNull() : draft.recipientOrganisation.trimmingCharacters(in: .whitespaces),
            "purpose": draft.purpose.trimmingCharacters(in: .whitespaces).isEmpty ? NSNull() : draft.purpose.trimmingCharacters(in: .whitespaces),
            "template": draft.template.rawValue,
            "item_ids": draft.itemIDs,
            "content": content,
            "allows_download": draft.allowsDownload,
            "expires_at": Self.timestamp(draft.duration.end(from: now)),
        ]
        var urlRequest = try await request(restURL.appending(path: "profile_shares"), query: [("select", "*")], method: "POST", json: row)
        urlRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let data = try await send(urlRequest, accepting: [201])
        guard let created = try? Self.decoder.decode([ShareRow].self, from: data).first else { throw ShareError.unavailable }
        return created.share
    }

    public func upload(pdf: Data, kind: String, shareID: String) async throws -> String {
        guard let token = await accessToken(), let userID = SupabaseVaultService.userID(fromToken: token) else { throw ShareError.notSignedIn }
        let path = "\(userID)/\(shareID.lowercased())/\(kind).pdf"
        var object = try await request(storageURL.appending(path: "object/\(Self.bucket)/\(path)"), method: "POST")
        object.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        object.setValue("true", forHTTPHeaderField: "x-upsert")
        object.httpBody = pdf
        object.timeoutInterval = 120
        _ = try await send(object, accepting: [200])
        return path
    }

    public func setDocuments(_ documents: [String: String], of share: ProfileShare) async throws {
        var content = share.content
        content.documents = documents
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(content))
        try await patch(share.id, ["content": json])
    }

    public func setPaused(_ isPaused: Bool, shareID: String) async throws {
        try await patch(shareID, ["paused_at": isPaused ? Self.timestamp(.now) : NSNull()])
    }

    public func extend(shareID: String, until: Date) async throws {
        try await patch(shareID, ["expires_at": Self.timestamp(until)])
    }

    public func revoke(_ share: ProfileShare) async throws {
        try await patch(share.id, ["revoked_at": Self.timestamp(.now)])
        let paths = Array((share.content.documents ?? [:]).values)
        guard !paths.isEmpty else { return }
        _ = try? await send(try await request(storageURL.appending(path: "object/\(Self.bucket)"), method: "DELETE", json: ["prefixes": paths]), accepting: [200])
    }

    public func employer(slug: String) async throws -> FairEmployer {
        let data = try await send(try await request(restURL.appending(path: "fair_employers"), query: [("select", "*"), ("slug", "eq.\(slug)")]))
        guard let employer = try? JSONDecoder().decode([FairEmployer].self, from: data).first else { throw ShareError.unavailable }
        return employer
    }

    // MARK: Saved profiles

    public func savedProfiles() async throws -> [SavedProfile] {
        let data = try await send(try await request(restURL.appending(path: "share_profiles"), query: [("select", "*"), ("order", "updated_at.desc"), ("limit", "50")]))
        guard let rows = try? Self.decoder.decode([ProfileRow].self, from: data) else { throw ShareError.unavailable }
        return rows.compactMap(\.profile)
    }

    public func save(_ profile: SavedProfile) async throws -> SavedProfile {
        let row: [String: Any] = [
            "name": profile.name.trimmingCharacters(in: .whitespaces),
            "template": profile.template.rawValue,
            "item_ids": profile.itemIDs,
            "brief_ids": profile.brief,
            "headline": profile.headline.trimmingCharacters(in: .whitespaces).isEmpty ? NSNull() : profile.headline.trimmingCharacters(in: .whitespaces),
            "includes_email": profile.includesEmail,
        ]
        let isNew = profile.id.isEmpty
        var urlRequest = try await request(
            restURL.appending(path: "share_profiles"), query: isNew ? [("select", "*")] : [("select", "*"), ("id", "eq.\(profile.id)")],
            method: isNew ? "POST" : "PATCH", json: row
        )
        urlRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let data = try await send(urlRequest, accepting: isNew ? [201] : [200])
        guard let kept = try? Self.decoder.decode([ProfileRow].self, from: data).first?.profile else { throw ShareError.unavailable }
        return kept
    }

    public func delete(profileID: String) async throws {
        _ = try await send(try await request(restURL.appending(path: "share_profiles"), query: [("id", "eq.\(profileID)")], method: "DELETE"), accepting: [200, 204])
    }

    struct ProfileRow: Decodable {
        let id: String
        let name: String
        let template: String
        let item_ids: [String]
        let brief_ids: [String]?
        let headline: String?
        let includes_email: Bool?
        let updated_at: Date

        var profile: SavedProfile? {
            guard let template = ShareTemplate(rawValue: template) else { return nil }
            return SavedProfile(
                id: id, name: name, template: template, itemIDs: item_ids, briefIDs: Set(brief_ids ?? []), headline: headline ?? "",
                includesEmail: includes_email ?? true, updatedAt: updated_at
            )
        }
    }

    // MARK: Plumbing

    private func patch(_ shareID: String, _ fields: [String: Any]) async throws {
        _ = try await send(try await request(restURL.appending(path: "profile_shares"), query: [("id", "eq.\(shareID)")], method: "PATCH", json: fields), accepting: [200, 204])
    }

    private func request(_ url: URL, query: [(String, String)] = [], method: String = "GET", json: Any? = nil) async throws -> URLRequest {
        guard let token = await accessToken() else { throw ShareError.notSignedIn }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        var urlRequest = URLRequest(url: components.url!, timeoutInterval: 30)
        urlRequest.httpMethod = method
        urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let json {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: json)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return urlRequest
    }

    private func send(_ urlRequest: URLRequest, accepting statuses: Set<Int> = [200]) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is URLError {
            throw ShareError.noConnection
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if statuses.contains(status) { return data }
        if status == 401 { throw ShareError.notSignedIn }
        // The table is missing until migration 20261125120000 has run.
        if status == 404 || String(decoding: data.prefix(300), as: UTF8.self).contains("PGRST205") { throw ShareError.notSetUp }
        throw ShareError.unavailable
    }

    static func timestamp(_ date: Date) -> String { date.formatted(.iso8601) }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            if let date = try? withFraction.parse(text) ?? Date.ISO8601FormatStyle().parse(text) { return date }
            // Postgres writes "2026-11-25 12:00:00.123+00" in some places.
            if let date = try? withFraction.parse(text.replacingOccurrences(of: " ", with: "T") + (text.hasSuffix("+00") ? ":00" : "")) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "date")
        }
        return decoder
    }()

    struct ShareRow: Decodable {
        let id: String
        let code: String
        let title: String
        let recipient_name: String
        let recipient_organisation: String?
        let purpose: String?
        let template: String
        let item_ids: [String]
        let content: ShareContent?
        let allows_download: Bool
        let expires_at: Date
        let paused_at: Date?
        let revoked_at: Date?
        let created_at: Date
        let profile_share_views: [LookRow]?

        struct LookRow: Decodable {
            let id: String
            let viewed_at: Date
            let action: String
            let viewer_name: String?
            let viewer_organisation: String?
        }

        var share: ProfileShare {
            ProfileShare(
                id: id, code: code, title: title, recipientName: recipient_name, recipientOrganisation: recipient_organisation, purpose: purpose,
                template: ShareTemplate(rawValue: template) ?? .employer, itemIDs: item_ids, content: content ?? ShareContent(profile: ShareProfile(name: "")),
                allowsDownload: allows_download, expiresAt: expires_at, pausedAt: paused_at, revokedAt: revoked_at, createdAt: created_at,
                looks: (profile_share_views ?? [])
                    .map { ShareLook(id: $0.id, date: $0.viewed_at, action: ShareLook.Action(rawValue: $0.action) ?? .view, viewerName: $0.viewer_name, viewerOrganisation: $0.viewer_organisation) }
                    .sorted { $0.date > $1.date }
            )
        }
    }
}
