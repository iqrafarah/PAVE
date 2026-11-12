import Foundation
import OSLog

/// The account's own name, photo and preferences in `profiles` (migration 20261112160000), with the session of the user.
public protocol ProfileService: Sendable {
    func profile() async throws -> PaveProfile
    func setPreferredName(_ name: String?) async throws
    func setPreferences(theme: PaveThemeColor, textSize: PaveTextSize, vaultLayout: PaveVaultLayout) async throws
    /// Uploads a JPEG as the new photo and returns its path; the old one is removed.
    func setAvatar(_ jpeg: Data, replacing oldPath: String?) async throws -> String
    func removeAvatar(_ path: String) async throws
    func avatarData(_ path: String) async throws -> Data
}

public struct SupabaseProfileService: ProfileService {
    static let logger = Logger(subsystem: "nl.fontys.pave", category: "profile")
    public static let bucket = "pave-avatars"

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

    public func profile() async throws -> PaveProfile {
        let userID = try await currentUserID()
        do {
            let data = try await send(try await request(profileURL(userID, select: "preferred_name,full_name,email,avatar_url,avatar_path,theme_color,text_size,vault_layout")))
            guard let row = try? JSONDecoder().decode([SettingsProfileRow].self, from: data).first else { return PaveProfile() }
            return row.profile(canChangeSettings: true)
        } catch ProfileError.notSetUp {
            // Before the migration: the name and photo from the organisation, nothing to change yet.
            let data = try await send(try await request(profileURL(userID, select: "preferred_name,full_name,email,avatar_url")))
            let row = try? JSONDecoder().decode([SettingsProfileRow].self, from: data).first
            return row?.profile(canChangeSettings: false) ?? PaveProfile(canChangeSettings: false)
        }
    }

    public func setPreferredName(_ name: String?) async throws {
        try await patch(["preferred_name": name.map { $0 as Any } ?? NSNull()])
    }

    public func setPreferences(theme: PaveThemeColor, textSize: PaveTextSize, vaultLayout: PaveVaultLayout) async throws {
        try await patch(["theme_color": theme.rawValue, "text_size": textSize.rawValue, "vault_layout": vaultLayout.rawValue])
    }

    public func setAvatar(_ jpeg: Data, replacing oldPath: String?) async throws -> String {
        let userID = try await currentUserID()
        let path = "\(userID)/\(UUID().uuidString.lowercased()).jpg"
        var upload = try await request(storageURL.appending(path: "object/\(Self.bucket)/\(path)"), method: "POST")
        upload.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        upload.setValue("false", forHTTPHeaderField: "x-upsert")
        upload.httpBody = jpeg
        upload.timeoutInterval = 60
        _ = try await send(upload)
        do {
            try await patch(["avatar_path": path])
        } catch {
            await removeObjects([path])
            throw error
        }
        if let oldPath { await removeObjects([oldPath]) }
        return path
    }

    public func removeAvatar(_ path: String) async throws {
        try await patch(["avatar_path": NSNull()])
        await removeObjects([path])
    }

    public func avatarData(_ path: String) async throws -> Data {
        var urlRequest = try await request(storageURL.appending(path: "object/authenticated/\(Self.bucket)/\(path)"))
        urlRequest.setValue("*/*", forHTTPHeaderField: "Accept")
        return try await send(urlRequest)
    }

    private func patch(_ fields: [String: Any]) async throws {
        let userID = try await currentUserID()
        var urlRequest = try await request(profileURL(userID, select: "id"), method: "PATCH")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: fields)
        let data = try await send(urlRequest)
        // Row-level security turns a refused change into "nothing changed": that is not a success.
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [Any], !rows.isEmpty else { throw ProfileError.notAllowed }
    }

    private func removeObjects(_ paths: [String]) async {
        guard var urlRequest = try? await request(storageURL.appending(path: "object/\(Self.bucket)"), method: "DELETE") else { return }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: ["prefixes": paths])
        _ = try? await send(urlRequest)
    }

    private func profileURL(_ userID: String, select: String) -> URL {
        var components = URLComponents(url: restURL.appending(path: "profiles"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: select), URLQueryItem(name: "id", value: "eq.\(userID)")]
        return components.url!
    }

    private func currentUserID() async throws -> String {
        guard let token = await accessToken(), let id = SupabaseVaultService.userID(fromToken: token) else { throw ProfileError.notSignedIn }
        return id
    }

    private func request(_ url: URL, method: String = "GET") async throws -> URLRequest {
        guard let token = await accessToken() else { throw ProfileError.notSignedIn }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.timeoutInterval = 20
        urlRequest.setValue(publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return urlRequest
    }

    private func send(_ urlRequest: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is URLError {
            throw ProfileError.noConnection
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(status) { return data }
        throw Self.error(status: status, body: data)
    }

    static func error(status: Int, body: Data) -> ProfileError {
        let detail = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let code = detail?["code"] as? String
        let message = (detail?["message"] as? String ?? detail?["error"] as? String ?? "").lowercased()
        logger.error("Profile request failed: \(status, privacy: .public) \(code ?? "-", privacy: .public)")
        if ["PGRST204", "42703"].contains(code) || message.contains("bucket not found") { return .notSetUp }
        if code == "42501" || status == 403 { return .notAllowed }
        if status == 401 { return .notSignedIn }
        return .unavailable
    }
}

struct SettingsProfileRow: Decodable {
    let preferred_name: String?
    let full_name: String?
    let email: String?
    let avatar_url: String?
    let avatar_path: String?
    let theme_color: String?
    let text_size: String?
    let vault_layout: String?

    func profile(canChangeSettings: Bool) -> PaveProfile {
        PaveProfile(
            preferredName: preferred_name,
            fullName: full_name,
            email: email,
            avatarPath: avatar_path,
            avatarURL: avatar_url.flatMap(URL.init(string:)),
            theme: theme_color.flatMap(PaveThemeColor.init(rawValue:)) ?? .green,
            textSize: text_size.flatMap(PaveTextSize.init(rawValue:)) ?? .standard,
            vaultLayout: vault_layout.flatMap(PaveVaultLayout.init(rawValue:)) ?? .grid,
            canChangeSettings: canChangeSettings
        )
    }
}
