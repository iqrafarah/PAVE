import Foundation
import OSLog

public protocol VaultService: Sendable {
    /// Everything in the vault of the signed-in user, the most recently changed first.
    func contents() async throws -> VaultContents
    /// Returns the id of the new item, so files and skills can be added to it.
    @discardableResult
    func add(_ draft: VaultItemDraft) async throws -> String
    /// Uploads the file to the private bucket and records it on the item. A cover or logo needs the `role` column
    /// (migration 20261112120000); without it they are refused with `missingColumn` and nothing stays behind.
    func attach(_ upload: VaultUpload, to itemID: String) async throws
    /// The bytes of one of your files, to show or open it. The bucket is private, so this goes with your session.
    func fileData(_ file: VaultItem.File) async throws -> Data
    /// Skills you add yourself: accepted straight away. Names that are already on the item are skipped by the server.
    func addSkills(_ names: [String], to itemID: String) async throws
    /// "Ayla mag dit bekijken en gebruiken": the standing yes for one item, which you can take back.
    func setAylaAllowed(_ allowed: Bool, itemID: String) async throws
    /// Archive: out of the vault, kept until it is put back or deleted.
    func setArchived(_ archived: Bool, itemID: String) async throws
    func update(_ draft: VaultItemDraft, itemID: String) async throws
    /// Puts the item in exactly these folders (none takes it out of every folder; it stays in the vault).
    func setFolders(_ folderIDs: [String], itemID: String) async throws
    /// Removes the attached files from storage first, then the item.
    func delete(_ item: VaultItem) async throws
    /// The colour and icon are saved only once `vault_folders` has those columns (`styleSaved` says whether they were).
    func createFolder(named name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> (folder: VaultFolder, styleSaved: Bool)
    func updateFolder(id: String, name: String, color: VaultFolderColor, icon: VaultFolderIcon) async throws -> Bool
    /// The items in the folder stay in the vault.
    func deleteFolder(id: String) async throws
    /// The folders in this order, the same on every device. Refused with `missingColumn` until `vault_folders` has a
    /// `position` (migration 20261113120000).
    func setFolderOrder(_ folderIDs: [String]) async throws
    /// "Eigen volgorde": each item at its place in this list. Refused with `missingColumn` like the folder order.
    func setItemOrder(_ itemIDs: [String]) async throws
    /// "Vastzetten": a pinned folder comes first. Refused with `missingColumn` until `vault_folders` has `pinned_at`
    /// (migration 20261119120000).
    func setFolderPinned(_ pinned: Bool, folderID: String) async throws
    /// Removes one file of an item: first from storage, then its row.
    func removeFile(_ file: VaultItem.File) async throws
    func removeSkills(_ names: [String], from itemID: String) async throws
    /// "Voorstel van Ayla": skills that fit the evidence. Only the fields of the draft go to Ayla, on request.
    /// `existing` are the skills already chosen for this evidence; `known` the other skills in the vault, which Ayla may
    /// propose again, written the same way.
    func suggestSkills(for draft: VaultItemDraft, material: VaultSkillsMaterial, existing: [String], known: [String]) async throws -> [VaultSkillSuggestion]
    /// "Laat Ayla invullen": the whole item, read from the documents. Only on request; nothing is stored.
    func proposeEvidence(from documents: [VaultEvidenceDocument], folders: [String], known: [String]) async throws -> [VaultEvidenceProposal]
    /// Read-only, MFA-protected directory choices for the verification request form.
    func validationOrganizations() async throws -> [VaultValidationOrganization]
    func validationLocations(organizationID: String) async throws -> [VaultValidationLocation]
    func validationDepartments(locationID: String) async throws -> [VaultValidationDepartment]
    func validationContacts(departmentID: String) async throws -> [VaultValidationContact]
    /// A page of organisations where someone may confirm this kind of evidence; `kind` nil for every kind.
    func searchValidationOrganizations(
        category: VaultCategory, query: String, kind: VaultOrganizationKind?, offset: Int
    ) async throws -> VaultValidationPage<VaultValidationOrganization>
    /// Organisations known by ID (from the evidence or an earlier request), also when nobody there may confirm it.
    func validationOrganizations(ids: [String], category: VaultCategory) async throws -> [VaultValidationOrganization]
    /// A page of the persons of one organisation who may confirm this kind of evidence, searched in the database.
    func searchValidationPeople(
        organizationID: String, category: VaultCategory, query: String, filters: VaultValidationFilters, offset: Int
    ) async throws -> VaultValidationPage<VaultValidationPerson>
    /// The location, department and function filters that lead to at least one of those persons.
    func validationFilterOptions(organizationID: String, category: VaultCategory) async throws -> [VaultValidationFilterOption]
    /// The persons this learner asked before, most recent first, as far as they may still confirm this kind of evidence.
    func previousValidationPeople(category: VaultCategory) async throws -> [VaultValidationPerson]
    /// Routes the request by trusted directory IDs. The server finds the account behind the person; the client never sends it.
    func requestValidation(
        itemID: String,
        organizationID: String,
        locationID: String,
        departmentID: String,
        contactID: String,
        message: String?
    ) async throws
}

public extension VaultService {
    func validationOrganizations() async throws -> [VaultValidationOrganization] { throw VaultError.notSetUp }
    func validationLocations(organizationID: String) async throws -> [VaultValidationLocation] { throw VaultError.notSetUp }
    func validationDepartments(locationID: String) async throws -> [VaultValidationDepartment] { throw VaultError.notSetUp }
    func validationContacts(departmentID: String) async throws -> [VaultValidationContact] { throw VaultError.notSetUp }
    func searchValidationOrganizations(
        category: VaultCategory, query: String, kind: VaultOrganizationKind?, offset: Int
    ) async throws -> VaultValidationPage<VaultValidationOrganization> { throw VaultError.notSetUp }
    func validationOrganizations(ids: [String], category: VaultCategory) async throws -> [VaultValidationOrganization] {
        throw VaultError.notSetUp
    }
    func searchValidationPeople(
        organizationID: String, category: VaultCategory, query: String, filters: VaultValidationFilters, offset: Int
    ) async throws -> VaultValidationPage<VaultValidationPerson> { throw VaultError.notSetUp }
    func validationFilterOptions(organizationID: String, category: VaultCategory) async throws -> [VaultValidationFilterOption] {
        throw VaultError.notSetUp
    }
    func previousValidationPeople(category: VaultCategory) async throws -> [VaultValidationPerson] { throw VaultError.notSetUp }
    func requestValidation(itemID: String, organizationID: String, locationID: String, departmentID: String, contactID: String, message: String?) async throws {
        throw VaultError.notSetUp
    }

    func setFolderOrder(_ folderIDs: [String]) async throws {
        throw VaultError.missingColumn
    }

    func setItemOrder(_ itemIDs: [String]) async throws {
        throw VaultError.missingColumn
    }

    func setArchived(_ archived: Bool, itemID: String) async throws {
        throw VaultError.unavailable
    }

    func setFolderPinned(_ pinned: Bool, folderID: String) async throws {
        throw VaultError.missingColumn
    }

    func proposeEvidence(from documents: [VaultEvidenceDocument], folders: [String], known: [String]) async throws -> [VaultEvidenceProposal] {
        throw VaultError.unavailable
    }
}

public enum VaultError: Error, Equatable, Sendable {
    case notSignedIn
    /// The session has no two-step verification, or the database refused the change.
    case notAllowed
    case noConnection
    case duplicateFolderName
    /// The database does not have a column or table the app uses yet (PostgREST code PGRST204 or PGRST205).
    case missingColumn
    /// The file is too large, empty or of a type the vault does not take.
    case fileRejected
    /// The Edge Function behind this is not deployed yet.
    case notSetUp
    case validationOrganisationNotFound
    case validationAlreadyPending
    case validationItemUnavailable
    case validationInvalidChoice
    /// The person may not confirm this kind of evidence.
    case validationNotAuthorized
    case unavailable

    public init(_ error: any Error) { self = (error as? VaultError) ?? .unavailable }
}

/// Reads and writes the `vault_*` tables with the session of the signed-in user. Row-level security keeps it to their own rows.
public struct SupabaseVaultService: VaultService {
    static let logger = Logger(subsystem: "nl.fontys.pave", category: "vault")
    /// The last request that failed, as "path status code message": shown under the error in debug builds.
    nonisolated(unsafe) public static var lastFailure: String?

    private let restURL: URL
    private let storageURL: URL
    private let functionsURL: URL
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
        functionsURL = projectURL.appending(path: "functions/v1")
        self.publishableKey = publishableKey
        self.session = session
        self.accessToken = accessToken
    }

    public func contents() async throws -> VaultContents {
        let base = "*,vault_item_skills(name,status),vault_item_files(*),vault_item_folders(folder_id)"
        do {
            return try await contents(select: base + ",vault_validation_requests(status,organisation_name,requested_at,response,organization_id)")
        } catch VaultError.missingColumn {
            // Without the requests the vault still loads; only "In afwachting" and the reason are missing.
        }
        do {
            return try await contents(select: base)
        } catch VaultError.missingColumn {
            // Before migration 20261112130000 there are no folder links yet: folder_id is the only folder.
            return try await contents(select: "*,vault_item_skills(name,status),vault_item_files(*)")
        }
    }

    private func contents(select: String) async throws -> VaultContents {
        let itemRequest = try await request(
            restURL.appending(path: "vault_items"),
            query: [("select", select), ("order", "updated_at.desc")]
        )
        async let itemData = send(itemRequest)
        async let folderData = folderRows()
        let (items, folders) = try await (itemData, folderData)
        guard
            let itemRows = try? JSONDecoder().decode([ItemRow].self, from: items),
            let folderRows = try? JSONDecoder().decode([FolderRow].self, from: folders)
        else { throw VaultError.unavailable }
        let all = itemRows.compactMap(\.item)
        return VaultContents(
            items: all.filter { $0.archivedAt == nil },
            folders: folderRows.map(\.folder),
            archived: all.filter { $0.archivedAt != nil }.sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) },
            canArchive: ((try? JSONDecoder().decode([ArchiveProbe].self, from: items)) ?? []).contains(where: \.hasColumn)
        )
    }

    @discardableResult
    public func add(_ draft: VaultItemDraft) async throws -> String {
        var urlRequest = try await request(
            restURL.appending(path: "vault_items"), query: [("select", "id")], method: "POST",
            json: draft.row.merging(["source": draft.filledByAyla ? "ayla" : "user"]) { $1 }
        )
        urlRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let data = try await send(urlRequest, accepting: [201])
        guard let id = try? JSONDecoder().decode([IDRow].self, from: data).first?.id else { throw VaultError.unavailable }
        // The item exists now and folder_id holds its first folder; extra folder links must never undo that.
        do {
            try await linkFolders(draft.folderIDs, itemID: id)
        } catch {
            Self.logger.error("Linking folders failed: \(String(describing: error), privacy: .public)")
        }
        return id
    }

    public func attach(_ upload: VaultUpload, to itemID: String) async throws {
        guard upload.problem == nil else { throw VaultError.fileRejected }
        guard let token = await accessToken() else { throw VaultError.notSignedIn }
        guard let userID = Self.userID(fromToken: token) else { throw VaultError.notSignedIn }
        let path = "\(userID)/\(itemID.lowercased())/\(UUID().uuidString.lowercased()).\(upload.fileExtension)"

        var object = try await request(storageURL.appending(path: "object/\(Self.bucket)/\(path)"), method: "POST")
        object.setValue(upload.mimeType, forHTTPHeaderField: "Content-Type")
        object.setValue("false", forHTTPHeaderField: "x-upsert")
        object.httpBody = upload.data
        object.timeoutInterval = 120
        _ = try await send(object, accepting: [200])

        var row: [String: Any] = [
            "item_id": itemID,
            "storage_path": path,
            "file_name": upload.fileName,
            "mime_type": upload.mimeType,
            "file_size_bytes": upload.data.count,
            "checksum_sha256": upload.checksum,
            "role": upload.role.rawValue,
        ]
        do {
            try await insertFile(row)
        } catch VaultError.missingColumn where upload.role == .document {
            row["role"] = nil
            do {
                try await insertFile(row)
            } catch {
                await removeObjects([path])
                throw error
            }
        } catch {
            await removeObjects([path])
            throw error
        }
    }

    public func fileData(_ file: VaultItem.File) async throws -> Data {
        var urlRequest = try await request(storageURL.appending(path: "object/authenticated/\(Self.bucket)/\(file.storagePath)"))
        urlRequest.setValue("*/*", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = 60
        return try await send(urlRequest)
    }

    public func addSkills(_ names: [String], to itemID: String) async throws {
        let rows = VaultSkills.cleaned(names).map { ["item_id": itemID, "name": $0] }
        guard !rows.isEmpty else { return }
        var urlRequest = try await request(restURL.appending(path: "vault_item_skills"), method: "POST", json: rows)
        urlRequest.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        _ = try await send(urlRequest, accepting: [201])
    }

    public func setAylaAllowed(_ allowed: Bool, itemID: String) async throws {
        let value: Any = allowed ? Date.now.formatted(.iso8601) : NSNull()
        _ = try await send(try await request(
            restURL.appending(path: "vault_items"), query: [("id", "eq.\(itemID)")], method: "PATCH", json: ["ayla_allowed_at": value]
        ), accepting: [200, 204])
    }

    public func setArchived(_ archived: Bool, itemID: String) async throws {
        let value: Any = archived ? Date.now.formatted(.iso8601) : NSNull()
        _ = try await send(try await request(
            restURL.appending(path: "vault_items"), query: [("id", "eq.\(itemID)")], method: "PATCH", json: ["archived_at": value]
        ), accepting: [200, 204])
    }

    public func removeFile(_ file: VaultItem.File) async throws {
        _ = try await send(try await request(
            storageURL.appending(path: "object/\(Self.bucket)"), method: "DELETE", json: ["prefixes": [file.storagePath]]
        ), accepting: [200])
        _ = try await send(try await request(
            restURL.appending(path: "vault_item_files"), query: [("id", "eq.\(file.id)")], method: "DELETE"
        ), accepting: [200, 204])
    }

    public func removeSkills(_ names: [String], from itemID: String) async throws {
        let names = VaultSkills.cleaned(names)
        guard !names.isEmpty else { return }
        let list = names.map { "\"\($0.replacingOccurrences(of: "\"", with: ""))\"" }.joined(separator: ",")
        _ = try await send(try await request(
            restURL.appending(path: "vault_item_skills"),
            query: [("item_id", "eq.\(itemID)"), ("name", "in.(\(list))")],
            method: "DELETE"
        ), accepting: [200, 204])
    }

    public func suggestSkills(for draft: VaultItemDraft, material: VaultSkillsMaterial, existing: [String], known: [String]) async throws -> [VaultSkillSuggestion] {
        let body: [String: Any] = [
            "category": draft.category.rawValue,
            "title": draft.title,
            "organisation": draft.organisationName,
            "description": draft.description,
            "existing": existing,
            "known": known,
            "files": material.texts.map { ["name": $0.name, "text": $0.text] },
            "images": material.images.map { ["name": $0.name, "data": $0.jpeg.base64EncodedString()] },
        ]
        var urlRequest = try await request(functionsURL.appending(path: "ayla-skills"), method: "POST", json: body)
        urlRequest.timeoutInterval = material.images.isEmpty ? 40 : 60
        let data = try await send(urlRequest)
        guard let response = try? JSONDecoder().decode(SkillSuggestionsResponse.self, from: data) else { throw VaultError.unavailable }
        return response.skills
    }

    public func proposeEvidence(from documents: [VaultEvidenceDocument], folders: [String], known: [String]) async throws -> [VaultEvidenceProposal] {
        let today = Date.now.formatted(.iso8601.year().month().day())
        let body: [String: Any] = [
            "documents": documents.map { document -> [String: Any] in
                var entry: [String: Any] = ["name": document.name]
                if let text = document.text { entry["text"] = text }
                if let image = document.image { entry["image"] = image.base64EncodedString() }
                return entry
            },
            "folders": folders,
            "today": today,
            "known": known,
        ]
        var urlRequest = try await request(functionsURL.appending(path: "ayla-evidence"), method: "POST", json: body)
        urlRequest.timeoutInterval = documents.contains { $0.image != nil } ? 75 : 50
        let data = try await send(urlRequest)
        guard let response = try? JSONDecoder().decode(EvidenceProposalsResponse.self, from: data) else { throw VaultError.unavailable }
        return response.items
    }

    private struct EvidenceProposalsResponse: Decodable {
        let items: [VaultEvidenceProposal]
    }

    /// Through `validation_organizations()`: `organizations` itself only lets you read your own
    /// organisation. Before that migration the table is all there is, which then shows only your own.
    public func validationOrganizations() async throws -> [VaultValidationOrganization] {
        do {
            let urlRequest = try await request(restURL.appending(path: "rpc/validation_organizations"), method: "POST", json: [String: Any]())
            let data = try await send(urlRequest)
            guard let rows = try? JSONDecoder().decode([VaultValidationOrganization].self, from: data) else { throw VaultError.unavailable }
            return rows
        } catch VaultError.missingColumn {
            return try await directoryRows(
                VaultValidationOrganization.self,
                table: "organizations",
                select: "id,name,kind",
                filters: [("kind", "not.is.null"), ("order", "name.asc")]
            )
        }
    }

    public func validationLocations(organizationID: String) async throws -> [VaultValidationLocation] {
        try await directoryRows(
            VaultValidationLocation.self,
            table: "organization_locations",
            select: "id,organization_id,city",
            filters: [("organization_id", "eq.\(organizationID)"), ("order", "city.asc")]
        )
    }

    public func validationDepartments(locationID: String) async throws -> [VaultValidationDepartment] {
        try await directoryRows(
            VaultValidationDepartment.self,
            table: "organization_departments",
            select: "id,location_id,name",
            filters: [("location_id", "eq.\(locationID)"), ("order", "name.asc")]
        )
    }

    /// Only the persons with a PAVE account, and never yourself: the database shows no others.
    public func validationContacts(departmentID: String) async throws -> [VaultValidationContact] {
        try await directoryRows(
            VaultValidationContact.self,
            table: "organization_contacts",
            select: "id,department_id,name,job_title,is_active",
            filters: [("department_id", "eq.\(departmentID)"), ("is_active", "eq.true"), ("order", "name.asc")]
        )
    }

    // Each of these falls back to the tables of before migration 20261124120000 while its functions are not there:
    // then the app filters and pages itself, and nobody is checked per kind of evidence yet (the server does that).

    public func searchValidationOrganizations(
        category: VaultCategory, query: String, kind: VaultOrganizationKind?, offset: Int
    ) async throws -> VaultValidationPage<VaultValidationOrganization> {
        do {
            return try await page(VaultValidationOrganization.self, function: "validation_search_organizations", parameters: [
                "p_category": category.rawValue,
                "p_query": query,
                "p_kind": kind?.rawValue ?? NSNull(),
                "p_limit": VaultValidationPage<VaultValidationOrganization>.size,
                "p_offset": offset,
            ])
        } catch VaultError.missingColumn {
            let found = try await validationOrganizations().filter { organization in
                (kind == nil || organization.organizationKind == kind) && Self.matches(organization.name, query)
            }
            return Self.page(of: found, offset: offset)
        }
    }

    public func validationOrganizations(ids: [String], category: VaultCategory) async throws -> [VaultValidationOrganization] {
        guard !ids.isEmpty else { return [] }
        do {
            return try await rpc([VaultValidationOrganization].self, "validation_organizations_by_id", [
                "p_category": category.rawValue,
                "p_ids": ids,
            ])
        } catch VaultError.missingColumn {
            return try await validationOrganizations().filter { ids.contains($0.id) }
        }
    }

    public func searchValidationPeople(
        organizationID: String, category: VaultCategory, query: String, filters: VaultValidationFilters, offset: Int
    ) async throws -> VaultValidationPage<VaultValidationPerson> {
        do {
            return try await page(VaultValidationPerson.self, function: "validation_search_contacts", parameters: [
                "p_organization_id": organizationID,
                "p_category": category.rawValue,
                "p_query": query,
                "p_location_id": filters.locationID ?? NSNull(),
                "p_department": filters.department ?? NSNull(),
                "p_function": filters.function ?? NSNull(),
                "p_limit": VaultValidationPage<VaultValidationPerson>.size,
                "p_offset": offset,
            ])
        } catch VaultError.missingColumn {
            let found = try await legacyPeople([("organization_departments.organization_locations.organization_id", "eq.\(organizationID)")])
                .filter { person in
                    (filters.locationID == nil || person.locationId == filters.locationID)
                        && (filters.department == nil || person.departmentName == filters.department)
                        && (filters.function == nil || person.function == filters.function)
                        && Self.matches([person.name, person.function, person.departmentName, person.city].joined(separator: " "), query)
                }
            return Self.page(of: found, offset: offset)
        }
    }

    public func validationFilterOptions(organizationID: String, category: VaultCategory) async throws -> [VaultValidationFilterOption] {
        do {
            return try await rpc([VaultValidationFilterOption].self, "validation_contact_filters", [
                "p_organization_id": organizationID,
                "p_category": category.rawValue,
            ])
        } catch VaultError.missingColumn {
            let people = try await legacyPeople([("organization_departments.organization_locations.organization_id", "eq.\(organizationID)")])
            func options(_ filter: VaultValidationFilterOption.Filter, _ key: (VaultValidationPerson) -> (String, String, String?))
                -> [VaultValidationFilterOption] {
                Dictionary(grouping: people.map(key), by: \.0).map { value, rows in
                    VaultValidationFilterOption(filter: filter, value: value, label: rows[0].1, locationId: rows[0].2, people: rows.count)
                }
                .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
            }
            return options(.location) { ($0.locationId, $0.city, nil) }
                + options(.department) { ($0.departmentId, $0.departmentName, $0.locationId) }
                + options(.function) { ($0.function, $0.function, nil) }
        }
    }

    public func previousValidationPeople(category: VaultCategory) async throws -> [VaultValidationPerson] {
        do {
            return try await rpc([VaultValidationPerson].self, "validation_previous_contacts", ["p_category": category.rawValue, "p_limit": 5])
        } catch VaultError.missingColumn {
            struct Previous: Decodable { let contactId: String }
            let previous = try await directoryRows(
                Previous.self,
                table: "vault_validation_requests",
                select: "contact_id",
                filters: [("contact_id", "not.is.null"), ("order", "requested_at.desc"), ("limit", "50")]
            )
            var ids = [String]()
            for row in previous where !ids.contains(row.contactId) { ids.append(row.contactId) }
            guard !ids.isEmpty else { return [] }
            let people = try await legacyPeople([("id", "in.(\(ids.joined(separator: ",")))")])
            let names = Dictionary((try? await validationOrganizations())?.map { ($0.id, $0.name) } ?? [], uniquingKeysWith: { first, _ in first })
            return ids.prefix(5).compactMap { id in
                people.first { $0.id == id }.map { person in
                    VaultValidationPerson(
                        id: person.id, name: person.name, jobTitle: person.jobTitle, departmentId: person.departmentId,
                        departmentName: person.departmentName, locationId: person.locationId, city: person.city,
                        organizationId: person.organizationId, organizationName: names[person.organizationId]
                    )
                }
            }
        }
    }

    /// The persons with department and location embedded, from the tables themselves. `!inner` drops a person whose
    /// department or location cannot be read.
    private func legacyPeople(_ filters: [(String, String)]) async throws -> [VaultValidationPerson] {
        struct Row: Decodable {
            struct Department: Decodable {
                struct Location: Decodable {
                    let id: String
                    let city: String
                    let organizationId: String
                }
                let id: String
                let name: String
                let organizationLocations: Location
            }
            let id: String
            let name: String
            let jobTitle: String?
            let organizationDepartments: Department
        }
        let rows = try await directoryRows(
            Row.self,
            table: "organization_contacts",
            select: "id,name,job_title,organization_departments!inner(id,name,organization_locations!inner(id,city,organization_id))",
            filters: filters + [("is_active", "eq.true"), ("order", "name.asc")]
        )
        return rows.map { row in
            VaultValidationPerson(
                id: row.id, name: row.name, jobTitle: row.jobTitle,
                departmentId: row.organizationDepartments.id, departmentName: row.organizationDepartments.name,
                locationId: row.organizationDepartments.organizationLocations.id,
                city: row.organizationDepartments.organizationLocations.city,
                organizationId: row.organizationDepartments.organizationLocations.organizationId
            )
        }
    }

    /// Every word of the query occurs in the text, ignoring case and accents: the same rule as the database.
    static func matches(_ text: String, _ query: String) -> Bool {
        query.split(whereSeparator: \.isWhitespace).allSatisfy {
            text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    static func page<Row>(of rows: [Row], offset: Int) -> VaultValidationPage<Row> {
        let start = min(max(offset, 0), rows.count)
        let end = min(start + VaultValidationPage<Row>.size, rows.count)
        return VaultValidationPage(rows: Array(rows[start..<end]), total: rows.count)
    }

    private func rpc<Result: Decodable>(_ type: Result.Type, _ function: String, _ parameters: [String: Any]) async throws -> Result {
        try Self.decodeDirectory(Result.self, from: try await rpcData(function, parameters))
    }

    /// One page of rows; every row carries `total_count`, the number of rows over all pages.
    private func page<Row: Decodable>(_ type: Row.Type, function: String, parameters: [String: Any]) async throws -> VaultValidationPage<Row> {
        let data = try await rpcData(function, parameters)
        let rows = try Self.decodeDirectory([Row].self, from: data)
        let total = try Self.decodeDirectory([PageTotal].self, from: data).first?.totalCount ?? 0
        return VaultValidationPage(rows: rows, total: total)
    }

    private struct PageTotal: Decodable { let totalCount: Int }

    private func rpcData(_ function: String, _ parameters: [String: Any]) async throws -> Data {
        try await send(try await request(restURL.appending(path: "rpc/\(function)"), method: "POST", json: parameters))
    }

    private static func decodeDirectory<Result: Decodable>(_ type: Result.Type, from data: Data) throws -> Result {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(Result.self, from: data)
        } catch {
            throw VaultError.unavailable
        }
    }

    private func directoryRows<Row: Decodable>(
        _ type: Row.Type,
        table: String,
        select: String,
        filters: [(String, String)]
    ) async throws -> [Row] {
        var query = [("select", select)]
        query.append(contentsOf: filters)
        let urlRequest = try await request(restURL.appending(path: table), query: query)
        let data = try await send(urlRequest)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode([Row].self, from: data)
        } catch {
            throw VaultError.unavailable
        }
    }

    public func requestValidation(
        itemID: String,
        organizationID: String,
        locationID: String,
        departmentID: String,
        contactID: String,
        message: String?
    ) async throws {
        let body: [String: Any] = [
            "action": "create",
            "itemId": itemID,
            "organizationId": organizationID,
            "locationId": locationID,
            "departmentId": departmentID,
            "contactId": contactID,
            "message": message ?? "",
        ]
        let urlRequest = try await request(functionsURL.appending(path: "vault-review"), method: "POST", json: body)
        _ = try await sendFunction(urlRequest)
    }

    private func insertFile(_ row: [String: Any]) async throws {
        _ = try await send(try await request(restURL.appending(path: "vault_item_files"), method: "POST", json: row), accepting: [201])
    }

    /// Clean-up after a failed step: the object is useless without its row.
    private func removeObjects(_ paths: [String]) async {
        guard let urlRequest = try? await request(
            storageURL.appending(path: "object/\(Self.bucket)"), method: "DELETE", json: ["prefixes": paths]
        ) else { return }
        _ = try? await send(urlRequest, accepting: [200])
    }

    /// The account id (`sub`) inside the access token, lowercased like the storage paths.
    static func userID(fromToken token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard
            let data = Data(base64Encoded: payload),
            let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let subject = claims["sub"] as? String,
            UUID(uuidString: subject) != nil
        else { return nil }
        return subject.lowercased()
    }

    public func update(_ draft: VaultItemDraft, itemID: String) async throws {
        _ = try await send(try await request(
            restURL.appending(path: "vault_items"), query: [("id", "eq.\(itemID)")], method: "PATCH", json: draft.row
        ), accepting: [200, 204])
        // The details are saved and folder_id holds the first folder; extra folder links must never undo that.
        do {
            try await replaceFolderLinks(draft.folderIDs, itemID: itemID)
        } catch {
            Self.logger.error("Linking folders failed: \(String(describing: error), privacy: .public)")
        }
    }

    public func setFolders(_ folderIDs: [String], itemID: String) async throws {
        _ = try await send(try await request(
            restURL.appending(path: "vault_items"),
            query: [("id", "eq.\(itemID)")],
            method: "PATCH",
            json: ["folder_id": folderIDs.first ?? NSNull()] as [String: Any]
        ), accepting: [200, 204])
        try await replaceFolderLinks(folderIDs, itemID: itemID)
    }

    /// Removes the item from every folder link and adds the new ones. Without the table (before the migration),
    /// folder_id already holds the first folder and that is all there is.
    private func replaceFolderLinks(_ folderIDs: [String], itemID: String) async throws {
        do {
            _ = try await send(try await request(
                restURL.appending(path: "vault_item_folders"), query: [("item_id", "eq.\(itemID)")], method: "DELETE"
            ), accepting: [200, 204])
        } catch VaultError.missingColumn {
            return
        }
        try await linkFolders(folderIDs, itemID: itemID)
    }

    private func linkFolders(_ folderIDs: [String], itemID: String) async throws {
        let rows = Array(Set(folderIDs)).map { ["item_id": itemID, "folder_id": $0] }
        guard !rows.isEmpty else { return }
        var urlRequest = try await request(restURL.appending(path: "vault_item_folders"), method: "POST", json: rows)
        urlRequest.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        do {
            _ = try await send(urlRequest, accepting: [200, 201])
        } catch VaultError.missingColumn {
            return
        }
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

    /// In your own order; before migration 20261113120000 there is no order yet, so oldest first.
    private func folderRows() async throws -> Data {
        let rows = { (order: String) async throws -> Data in
            try await self.send(try await self.request(self.restURL.appending(path: "vault_folders"), query: [("select", "*"), ("order", order)]))
        }
        do {
            return try await rows("position.asc.nullslast,created_at.asc")
        } catch VaultError.missingColumn {
            return try await rows("created_at.asc")
        }
    }

    public func setFolderOrder(_ folderIDs: [String]) async throws {
        try await setPositions(folderIDs, table: "vault_folders")
    }

    public func setItemOrder(_ itemIDs: [String]) async throws {
        try await setPositions(itemIDs, table: "vault_items")
    }

    public func setFolderPinned(_ pinned: Bool, folderID: String) async throws {
        let value: Any = pinned ? ISO8601DateFormatter().string(from: .now) : NSNull()
        _ = try await send(try await request(
            restURL.appending(path: "vault_folders"), query: [("id", "eq.\(folderID)")], method: "PATCH", json: ["pinned_at": value]
        ), accepting: [200, 204])
    }

    private func setPositions(_ ids: [String], table: String) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (position, id) in ids.enumerated() {
                group.addTask {
                    _ = try await self.send(try await self.request(
                        self.restURL.appending(path: table), query: [("id", "eq.\(id)")], method: "PATCH", json: ["position": position]
                    ), accepting: [200, 204])
                }
            }
            try await group.waitForAll()
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
        json: Any? = nil
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
        let failure = Self.error(status: status, body: data)
        let detail = try? JSONDecoder().decode(PostgrestError.self, from: data)
        Self.lastFailure = "\(urlRequest.httpMethod ?? "") \(urlRequest.url?.path() ?? "") \(status) \(detail?.code ?? "") \(detail?.message ?? String(decoding: data.prefix(160), as: UTF8.self))"
        throw failure
    }

    /// Edge Function errors use `{ error: "..." }`, unlike PostgREST's `{ code, message }` payload.
    private func sendFunction(_ urlRequest: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is URLError {
            throw VaultError.noConnection
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let detail = try? JSONDecoder().decode(FunctionError.self, from: data)
            switch detail?.error {
            case .some("organization_not_found"): throw VaultError.validationOrganisationNotFound
            case .some("already_pending"): throw VaultError.validationAlreadyPending
            case .some("item_not_awaiting_verification"): throw VaultError.validationItemUnavailable
            case .some("invalid_choice"): throw VaultError.validationInvalidChoice
            case .some("not_authorized"): throw VaultError.validationNotAuthorized
            default: throw Self.error(status: status, body: data)
            }
        }
        return data
    }

    static func error(status: Int, body: Data) -> VaultError {
        let detail = try? JSONDecoder().decode(PostgrestError.self, from: body)
        logger.error("Vault request failed: \(status, privacy: .public) \(detail?.code ?? "-", privacy: .public) \(detail?.message ?? "", privacy: .public)")
        let code = detail?.code
        if code == "23505" { return .duplicateFolderName }
        // A column, a table or a relation between tables that the database does not have yet (PostgREST or Postgres codes).
        // PGRST202: a database function that is not there yet.
        if ["PGRST204", "PGRST205", "PGRST200", "PGRST202", "42P01", "42703"].contains(code) { return .missingColumn }
        // A database that does not take a logo yet: its role check is older than the app (migration 20261112140000).
        if code == "23514", detail?.message?.contains("vault_item_files_role_check") == true { return .missingColumn }
        if code == "NOT_FOUND", status == 404 { return .notSetUp }
        switch status {
        case 401: return .notSignedIn
        case 403: return .notAllowed
        default: return .unavailable
        }
    }
}

private struct PostgrestError: Decodable {
    let code: String?
    let message: String?
}

private struct FunctionError: Decodable {
    let error: String?
}

private struct IDRow: Decodable {
    let id: String
}

struct ItemRow: Decodable {
    struct SkillRow: Decodable {
        let name: String
        let status: String
    }

    struct FolderLinkRow: Decodable {
        let folder_id: String
    }

    struct RequestRow: Decodable {
        let status: String
        let organisation_name: String
        let requested_at: String
        let response: String?
        let organization_id: String?
    }

    struct FileRow: Decodable {
        let id: String
        let file_name: String
        let mime_type: String
        let storage_path: String
        let role: String?
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
    let ayla_allowed_at: String?
    let position: Int?
    let archived_at: String?
    let organization_id: String?
    let vault_item_skills: [SkillRow]?
    let vault_item_files: [FileRow]?
    let vault_item_folders: [FolderLinkRow]?
    let vault_validation_requests: [RequestRow]?

    /// `nil` for a category or status this version of the app does not know yet.
    var item: VaultItem? {
        guard
            let category = VaultCategory(rawValue: category),
            let status = VaultItem.Status(rawValue: verification_status)
        else { return nil }
        var item = VaultItem(
            id: id,
            folderIDs: Self.folderIDs(first: folder_id, links: vault_item_folders),
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
                VaultItem.File(
                    id: $0.id,
                    name: $0.file_name,
                    mimeType: $0.mime_type,
                    storagePath: $0.storage_path,
                    role: $0.role.flatMap(VaultFileRole.init) ?? .document
                )
            },
            aylaAllowedAt: ayla_allowed_at.map(SupabaseAylaService.date(from:)),
            createdAt: SupabaseAylaService.date(from: created_at),
            updatedAt: SupabaseAylaService.date(from: updated_at),
            position: position,
            lastRequest: Self.lastRequest(in: vault_validation_requests)
        )
        item.archivedAt = archived_at.map(SupabaseAylaService.date(from:))
        item.organizationID = organization_id
        return item
    }

    /// The newest request; a status this version of the app does not know is skipped.
    static func lastRequest(in rows: [RequestRow]?) -> VaultItem.ValidationRequest? {
        (rows ?? [])
            .compactMap { row -> VaultItem.ValidationRequest? in
                guard let status = VaultItem.ValidationRequest.Status(rawValue: row.status) else { return nil }
                return VaultItem.ValidationRequest(
                    status: status,
                    organisationName: row.organisation_name,
                    requestedAt: SupabaseAylaService.date(from: row.requested_at),
                    response: row.response,
                    organizationID: row.organization_id
                )
            }
            .max { $0.requestedAt < $1.requestedAt }
    }
}

/// Whether the rows carry `archived_at`: false before the migration with the archive (20261120120000).
private struct ArchiveProbe: Decodable {
    let hasColumn: Bool

    private enum CodingKeys: String, CodingKey {
        case archivedAt = "archived_at"
    }

    init(from decoder: any Decoder) throws {
        hasColumn = try decoder.container(keyedBy: CodingKeys.self).contains(.archivedAt)
    }
}

private struct SkillSuggestionsResponse: Decodable {
    let skills: [VaultSkillSuggestion]
}

extension ItemRow {
    /// The linked folders, and folder_id for an item that older clients put in a folder; each once, the first first.
    static func folderIDs(first: String?, links: [FolderLinkRow]?) -> [String] {
        var ids: [String] = first.map { [$0] } ?? []
        for link in links ?? [] where !ids.contains(link.folder_id) { ids.append(link.folder_id) }
        return ids
    }
}

struct FolderRow: Decodable {
    let id: String
    let name: String
    let color: String?
    let icon: String?
    let created_at: String
    let pinned_at: String?

    var folder: VaultFolder {
        VaultFolder(
            id: id,
            name: name,
            color: color.flatMap { VaultFolderColor(rawValue: $0) },
            icon: icon.flatMap(VaultFolderIcon.init),
            createdAt: SupabaseAylaService.date(from: created_at),
            pinnedAt: pinned_at.map(SupabaseAylaService.date(from:))
        )
    }
}
