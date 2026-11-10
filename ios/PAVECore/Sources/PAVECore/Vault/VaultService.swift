import Foundation

public protocol VaultService: Sendable {
    /// Everything in the vault of the signed-in user, the most recently changed first.
    func contents() async throws -> VaultContents
    func add(_ draft: VaultItemDraft) async throws
    func update(_ draft: VaultItemDraft, itemID: String) async throws
    /// `nil` takes the item out of its folder; it stays in the vault.
    func move(itemID: String, to folderID: String?) async throws
    /// Removes the attached files from storage first, then the item.
    func delete(_ item: VaultItem) async throws
    /// The colour and icon are saved only once `vault_folders` has those columns (`styleSaved` says whether they were).
    func createFolder(named name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> (folder: VaultFolder, styleSaved: Bool)
    func updateFolder(id: String, name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> Bool
    /// The items in the folder stay in the vault.
    func deleteFolder(id: String) async throws
}

public enum VaultError: Error, Equatable, Sendable {
    case notSignedIn
    /// The session has no two-step verification, or the database refused the change.
    case notAllowed
    case noConnection
    case duplicateFolderName
    /// The database does not have a column the app sent yet (PostgREST code PGRST204).
    case missingColumn
    case unavailable

    public init(_ error: any Error) { self = (error as? VaultError) ?? .unavailable }
}

/// Reads and writes the `vault_*` tables with the session of the signed-in user. Row-level security keeps it to their own rows.
public struct SupabaseVaultService: VaultService {
    private let restURL: URL
    private let storageURL: URL
    private let publishableKey: String
    private let session: URLSession
    private let accessToken: @Sendable () async -> String?

    public static let bucket = "pave-vault"

    public init(
        projectURL: URL,
        publishableKey: String,
        session: URLSession = .shared,
        accessToken: @escaping @Sendable () async -> String?
    ) {
        restURL = projectURL.appending(path: "rest/v1")
        storageURL = projectURL.appending(path: "storage/v1")
        self.publishableKey = publishableKey
        self.session = session
        self.accessToken = accessToken
    }

    public func contents() async throws -> VaultContents {
        let itemRequest = try await request(
            restURL.appending(path: "vault_items"),
            query: [
                ("select", "*,vault_item_skills(name,status),vault_item_files(id,file_name,mime_type,storage_path)"),
                ("order", "updated_at.desc"),
            ]
        )
        let folderRequest = try await request(
            restURL.appending(path: "vault_folders"),
            query: [("select", "*"), ("order", "created_at.asc")]
        )
        async let itemData = send(itemRequest)
        async let folderData = send(folderRequest)
        let (items, folders) = try await (itemData, folderData)
        guard
            let itemRows = try? JSONDecoder().decode([ItemRow].self, from: items),
            let folderRows = try? JSONDecoder().decode([FolderRow].self, from: folders)
        else { throw VaultError.unavailable }
        return VaultContents(items: itemRows.compactMap(\.item), folders: folderRows.map(\.folder))
    }

    public func add(_ draft: VaultItemDraft) async throws {
        _ = try await send(try await request(restURL.appending(path: "vault_items"), method: "POST", json: draft.row), accepting: [201])
    }

    public func update(_ draft: VaultItemDraft, itemID: String) async throws {
        _ = try await send(try await request(
            restURL.appending(path: "vault_items"), query: [("id", "eq.\(itemID)")], method: "PATCH", json: draft.row
        ), accepting: [200, 204])
    }

    public func move(itemID: String, to folderID: String?) async throws {
        _ = try await send(try await request(
            restURL.appending(path: "vault_items"),
            query: [("id", "eq.\(itemID)")],
            method: "PATCH",
            json: ["folder_id": folderID ?? NSNull()]
        ), accepting: [200, 204])
    }

    public func delete(_ item: VaultItem) async throws {
        if !item.files.isEmpty {
            _ = try await send(try await request(
                storageURL.appending(path: "object/\(Self.bucket)"),
                method: "DELETE",
                json: ["prefixes": item.files.map(\.storagePath)]
            ), accepting: [200])
        }
        _ = try await send(try await request(
            restURL.appending(path: "vault_items"), query: [("id", "eq.\(item.id)")], method: "DELETE"
        ), accepting: [200, 204])
    }

    public func createFolder(
        named name: String, color: VaultFolderColor, icon: VaultFolderIcon
    ) async throws -> (folder: VaultFolder, styleSaved: Bool) {
        let create = { (json: [String: Any]) async throws -> VaultFolder in
            var urlRequest = try await request(restURL.appending(path: "vault_folders"), method: "POST", json: json)
            urlRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
            let data = try await send(urlRequest, accepting: [201])
            guard let row = try? JSONDecoder().decode([FolderRow].self, from: data).first else { throw VaultError.unavailable }
            return row.folder
        }
        do {
            return (try await create(["name": name, "color": color.rawValue, "icon": icon.rawValue]), true)
        } catch VaultError.missingColumn {
            return (try await create(["name": name]), false)
        }
    }

    public func updateFolder(id: String, name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> Bool {
        let update = { (json: [String: Any]) async throws in
            _ = try await send(try await request(
                restURL.appending(path: "vault_folders"), query: [("id", "eq.\(id)")], method: "PATCH", json: json
            ), accepting: [200, 204])
        }
        do {
            try await update(["name": name, "color": color.rawValue, "icon": icon.rawValue])
            return true
        } catch VaultError.missingColumn {
            try await update(["name": name])
            return false
        }
    }

    public func deleteFolder(id: String) async throws {
        _ = try await send(try await request(
            restURL.appending(path: "vault_folders"), query: [("id", "eq.\(id)")], method: "DELETE"
        ), accepting: [200, 204])
    }

    private func request(
        _ url: URL,
        query: [(String, String)] = [],
        method: String = "GET",
        json: [String: Any]? = nil
    ) async throws -> URLRequest {
        guard let token = await accessToken() else { throw VaultError.notSignedIn }
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
            throw VaultError.noConnection
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if statuses.contains(status) { return data }
        throw Self.error(status: status, body: data)
    }

    static func error(status: Int, body: Data) -> VaultError {
        let code = (try? JSONDecoder().decode(PostgrestError.self, from: body))?.code
        if code == "23505" { return .duplicateFolderName }
        if code == "PGRST204" { return .missingColumn }
        switch status {
        case 401: return .notSignedIn
        case 403: return .notAllowed
        default: return .unavailable
        }
    }
}

private struct PostgrestError: Decodable {
    let code: String?
}

struct ItemRow: Decodable {
    struct SkillRow: Decodable {
        let name: String
        let status: String
    }

    struct FileRow: Decodable {
        let id: String
        let file_name: String
        let mime_type: String
        let storage_path: String
    }

    let id: String
    let folder_id: String?
    let category: String
    let title: String
    let description: String?
    let organisation_name: String?
    let organisation_location: String?
    let start_date: String?
    let end_date: String?
    let issued_on: String?
    let is_current: Bool
    let verification_status: String
    let source: String
    let created_at: String
    let updated_at: String
    let vault_item_skills: [SkillRow]?
    let vault_item_files: [FileRow]?

    /// `nil` for a category or status this version of the app does not know yet.
    var item: VaultItem? {
        guard
            let category = VaultCategory(rawValue: category),
            let status = VaultItem.Status(rawValue: verification_status)
        else { return nil }
        return VaultItem(
            id: id,
            folderID: folder_id,
            category: category,
            title: title,
            description: description,
            organisationName: organisation_name,
            organisationLocation: organisation_location,
            startDate: start_date.flatMap(VaultDay.init),
            endDate: end_date.flatMap(VaultDay.init),
            issuedOn: issued_on.flatMap(VaultDay.init),
            isCurrent: is_current,
            status: status,
            source: VaultItem.Source(rawValue: source) ?? .user,
            skills: (vault_item_skills ?? []).filter { $0.status == "accepted" }.map(\.name).sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            },
            files: (vault_item_files ?? []).map {
                VaultItem.File(id: $0.id, name: $0.file_name, mimeType: $0.mime_type, storagePath: $0.storage_path)
            },
            createdAt: SupabaseAylaService.date(from: created_at),
            updatedAt: SupabaseAylaService.date(from: updated_at)
        )
    }
}

struct FolderRow: Decodable {
    let id: String
    let name: String
    let color: String?
    let icon: String?
    let created_at: String

    var folder: VaultFolder {
        VaultFolder(
            id: id,
            name: name,
            color: color.flatMap(VaultFolderColor.init),
            icon: icon.flatMap(VaultFolderIcon.init),
            createdAt: SupabaseAylaService.date(from: created_at)
        )
    }
}
