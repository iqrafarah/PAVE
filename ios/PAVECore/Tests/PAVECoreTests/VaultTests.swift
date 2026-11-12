import Foundation
import Testing
@testable import PAVECore

struct VaultDayTests {
    @Test func readsDatabaseDates() {
        #expect(VaultDay("2025-03-01") == VaultDay(year: 2025, month: 3, day: 1))
        #expect(VaultDay("2025-03-01T00:00:00Z") == VaultDay(year: 2025, month: 3, day: 1))
        #expect(VaultDay("2025-13-01") == nil)
        #expect(VaultDay("maart") == nil)
        #expect(VaultDay(year: 2025, month: 3, day: 1).text == "2025-03-01")
    }

    @Test func writesDutchMonths() {
        #expect(VaultDay(year: 2025, month: 3, day: 1).monthAndYear == "mrt 2025")
        #expect(VaultDay(year: 2026, month: 10, day: 7).full == "7 okt 2026")
    }
}

struct VaultItemTests {
    private func item(
        category: VaultCategory = .workExperience,
        start: String? = nil,
        end: String? = nil,
        issued: String? = nil,
        isCurrent: Bool = false
    ) -> VaultItem {
        VaultItem(
            id: "1", category: category, title: "Stage",
            startDate: start.flatMap(VaultDay.init), endDate: end.flatMap(VaultDay.init),
            issuedOn: issued.flatMap(VaultDay.init), isCurrent: isCurrent
        )
    }

    @Test func describesThePeriod() {
        #expect(item(start: "2025-03-01", end: "2025-12-31").period == "mrt 2025 - dec 2025")
        #expect(item(start: "2025-11-01", end: "2026-01-01", isCurrent: true).period == "nov 2025 - nu")
        #expect(item(start: "2025-03-01", end: "2025-03-20").period == "mrt 2025")
        #expect(item(start: "2025-03-01").period == "vanaf mrt 2025")
        #expect(item(end: "2025-03-01").period == "tot mrt 2025")
        #expect(item(category: .diplomas, issued: "2025-07-01").period == "jul 2025")
        #expect(item().period == nil)
    }

    @Test func changingAConfirmedItemNeedsConfirmingAgain() {
        #expect(!VaultItem(id: "1", category: .projects, title: "A").changeNeedsReconfirmation)
        #expect(!VaultItem(id: "1", category: .projects, title: "A", status: .rejected).changeNeedsReconfirmation)
        #expect(VaultItem(id: "1", category: .projects, title: "A", status: .verified).changeNeedsReconfirmation)
    }

    @Test func joinsOrganisationAndPlace() {
        #expect(VaultItem(id: "1", category: .projects, title: "A", organisationName: "Pixelwerk", organisationLocation: "Eindhoven").place == "Pixelwerk, Eindhoven")
        #expect(VaultItem(id: "1", category: .projects, title: "A", organisationName: " ", organisationLocation: "Eindhoven").place == "Eindhoven")
        #expect(VaultItem(id: "1", category: .projects, title: "A").place == nil)
    }
}

struct VaultItemDraftTests {
    @Test func checksLikeTheDatabase() {
        var draft = VaultItemDraft(category: .internships)
        #expect(draft.problem == .missingTitle)
        draft.title = "   "
        #expect(draft.problem == .missingTitle)
        draft.title = String(repeating: "a", count: 201)
        #expect(draft.problem == .titleTooLong)
        draft.title = "Stage"
        draft.startDate = VaultDay(year: 2025, month: 6, day: 1)
        draft.endDate = VaultDay(year: 2025, month: 3, day: 1)
        #expect(draft.problem == .endBeforeStart)
        draft.isCurrent = true
        #expect(draft.problem == nil)
    }

    @Test func keepsOnlyTheDatesThatFitTheCategory() {
        var draft = VaultItemDraft(category: .diplomas)
        draft.title = "  Propedeuse HBO-ICT "
        draft.issuedOn = VaultDay(year: 2025, month: 7, day: 1)
        draft.startDate = VaultDay(year: 2024, month: 9, day: 1)
        draft.organisationName = "  "
        let diploma = draft.row
        #expect(diploma["title"] as? String == "Propedeuse HBO-ICT")
        #expect(diploma["issued_on"] as? String == "2025-07-01")
        #expect(diploma["start_date"] is NSNull)
        #expect(diploma["organisation_name"] is NSNull)
        #expect(diploma["is_current"] as? Bool == false)

        draft.category = .workExperience
        draft.isCurrent = true
        draft.endDate = VaultDay(year: 2025, month: 1, day: 1)
        let work = draft.row
        #expect(work["start_date"] as? String == "2024-09-01")
        #expect(work["end_date"] is NSNull)
        #expect(work["issued_on"] is NSNull)
        #expect(work["is_current"] as? Bool == true)
        #expect(work["status"] == nil && work["verification_status"] == nil && work["source"] == nil)
        #expect(JSONSerialization.isValidJSONObject(work))
    }
}

struct VaultFilterTests {
    private let items = [
        VaultItem(id: "diploma", category: .diplomas, title: "Propedeuse", issuedOn: VaultDay("2024-07-01"), status: .verified, source: .organization),
        VaultItem(id: "stage", folderIDs: ["f"], category: .internships, title: "Stage Pixelwerk", startDate: VaultDay("2025-02-01"), endDate: VaultDay("2025-07-01"), skills: ["Swift"]),
        VaultItem(id: "baan", category: .workExperience, title: "Teamleider", startDate: VaultDay("2023-01-01"), isCurrent: true, status: .rejected),
    ]
    private let today = VaultDay(year: 2026, month: 11, day: 10)

    @Test func sortsOnTheDateThatMatters() {
        var filter = VaultFilter()
        #expect(filter.apply(to: items, today: today).map(\.id) == ["baan", "stage", "diploma"])
        filter.order = .oldest
        #expect(filter.apply(to: items, today: today).map(\.id) == ["diploma", "stage", "baan"])
    }

    @Test func filtersOnShelfStatusOriginAndSearch() {
        var filter = VaultFilter()
        filter.shelf = .category(.diplomas)
        #expect(filter.apply(to: items, today: today).map(\.id) == ["diploma"])
        filter.shelf = .folder("f")
        #expect(filter.apply(to: items, today: today).map(\.id) == ["stage"])
        filter.shelf = .all
        filter.status = .rejected
        #expect(filter.apply(to: items, today: today).map(\.id) == ["baan"])
        filter.status = nil
        filter.origin = .organisation
        #expect(filter.apply(to: items, today: today).map(\.id) == ["diploma"])
        #expect(filter.narrowsDown)
        filter.origin = nil
        filter.searchText = "swift"
        #expect(filter.apply(to: items, today: today).map(\.id) == ["stage"])
        filter.searchText = "stages"
        #expect(filter.apply(to: items, today: today).map(\.id) == ["stage"])
    }
}

struct SupabaseVaultServiceTests {
    @Test func readsAnItemRowWithSkillsAndFiles() throws {
        let json = """
        [{"id":"a","user_id":"u","folder_id":null,"category":"internships","title":"Stage","description":null,
          "organisation_name":"Pixelwerk","organisation_location":"Eindhoven","start_date":"2025-02-01","end_date":"2025-07-01",
          "issued_on":null,"is_current":false,"verification_status":"verified","source":"organization",
          "created_at":"2026-11-10T10:00:00.123+00:00","updated_at":"2026-11-10T10:00:00+00:00",
          "vault_item_skills":[{"name":"Swift","status":"accepted"},{"name":"Scrum","status":"proposed"},{"name":"Git","status":"accepted"}],
          "vault_item_files":[{"id":"f","file_name":"verslag.pdf","mime_type":"application/pdf","storage_path":"u/a/f.pdf"}]},
         {"id":"b","category":"somethingNew","title":"X","is_current":false,"verification_status":"toVerify","source":"user",
          "created_at":"2026-11-10T10:00:00Z","updated_at":"2026-11-10T10:00:00Z"}]
        """
        let rows = try JSONDecoder().decode([ItemRow].self, from: Data(json.utf8))
        let items = rows.compactMap(\.item)
        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.status == .verified)
        #expect(item.source == .organization)
        #expect(item.skills == ["Git", "Swift"])
        #expect(item.files.map(\.storagePath) == ["u/a/f.pdf"])
        #expect(item.period == "feb 2025 - jul 2025")
        #expect(item.createdAt != .distantPast)
    }

    @Test func mapsDatabaseErrors() {
        let duplicate = Data(#"{"code":"23505","message":"duplicate key"}"#.utf8)
        #expect(SupabaseVaultService.error(status: 409, body: duplicate) == .duplicateFolderName)
        #expect(SupabaseVaultService.error(status: 401, body: Data()) == .notSignedIn)
        #expect(SupabaseVaultService.error(status: 403, body: Data(#"{"code":"42501"}"#.utf8)) == .notAllowed)
        #expect(SupabaseVaultService.error(status: 500, body: Data()) == .unavailable)
        #expect(SupabaseVaultService.error(status: 400, body: Data(#"{"code":"PGRST204","message":"Could not find the 'color' column"}"#.utf8)) == .missingColumn)
    }

    @Test func readsFolderStyleWhenTheColumnsExist() throws {
        let json = #"[{"id":"a","name":"Stage","color":"rose","icon":"rocket-launch","created_at":"2026-11-10T10:00:00Z"},{"id":"b","name":"Oud","created_at":"2026-11-10T10:00:00Z"},{"id":"c","name":"Raar","color":"neon","icon":"x","created_at":"2026-11-10T10:00:00Z"}]"#
        let folders = try JSONDecoder().decode([FolderRow].self, from: Data(json.utf8)).map(\.folder)
        #expect(folders[0].color == .rose && folders[0].icon == .rocket)
        #expect(folders[1].color == nil && folders[1].icon == nil)
        #expect(folders[2].color == nil && folders[2].icon == nil)
    }

    @Test func folderStyleCodesMatchTheMigration() throws {
        let migration = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "shared/supabase/migrations/20261110170000_vault_cleanup_and_evidence_flow.sql")
        let sql = try String(contentsOf: migration, encoding: .utf8)
        for color in VaultFolderColor.allCases { #expect(sql.contains("'\(color.rawValue)'")) }
        for icon in VaultFolderIcon.allCases { #expect(sql.contains("'\(icon.rawValue)'")) }
    }

    @Test func aylaCategoriesMapToVaultCategories() {
        #expect(AylaVaultCategory.workExperience.category == .workExperience)
        #expect(AylaVaultCategory(rawValue: "somethingNew").category == nil)
        #expect(Set(VaultCategory.allCases.map(\.rawValue)) == [
            "diplomas", "certificates", "badges", "projects", "workExperience", "internships", "skills", "feedback", "reflections", "other",
        ])
    }
}

struct VaultUploadTests {
    @Test func checksLikeTheBucket() {
        #expect(VaultUpload(data: Data([1]), fileName: "verslag.pdf", mimeType: "application/pdf").problem == nil)
        #expect(VaultUpload(data: Data(), fileName: "leeg.pdf", mimeType: "application/pdf").problem == .empty)
        #expect(VaultUpload(data: Data(count: VaultUpload.maximumBytes + 1), fileName: "groot.pdf", mimeType: "application/pdf").problem == .tooLarge)
        #expect(VaultUpload(data: Data([1]), fileName: "film.mov", mimeType: "video/quicktime").problem == .unsupportedType)
        #expect(VaultUpload(data: Data([1]), fileName: "cv.pdf", mimeType: "application/pdf", role: .cover).problem == .notAnImage)
        #expect(VaultUpload(data: Data([1]), fileName: "foto.png", mimeType: "IMAGE/PNG", role: .cover).problem == nil)
    }

    @Test func describesTheFileLikeTheForm() {
        let upload = VaultUpload(data: Data(count: 2_400_000), fileName: "LiveWall-eindstage_verslag.pdf", mimeType: "application/pdf")
        #expect(upload.summary.hasPrefix("PDF - "))
        #expect(upload.summary.hasSuffix("MB"))
        #expect(upload.suggestedTitle == "LiveWall eindstage verslag")
        #expect(VaultUpload.mimeType(forExtension: "JPG") == "image/jpeg")
        #expect(VaultUpload.mimeType(forExtension: "docx") == "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        #expect(VaultUpload.mimeType(forExtension: "exe") == nil)
    }

    @Test func checksumIsSha256Hex() {
        let upload = VaultUpload(data: Data("abc".utf8), fileName: "a.txt", mimeType: "text/plain")
        #expect(upload.checksum == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func typesMatchTheMigration() throws {
        let sql = try String(contentsOf: VaultMigration.url("20261110120000_vault.sql"), encoding: .utf8)
        for type in VaultUpload.allowedTypes { #expect(sql.contains("'\(type)'")) }
        #expect(sql.contains("\(VaultUpload.maximumBytes)"))
        let cover = try String(contentsOf: VaultMigration.url("20261112120000_vault_cover_example_folders_reverify.sql"), encoding: .utf8)
        for type in VaultUpload.imageTypes { #expect(cover.contains("'\(type)'")) }
    }
}

struct VaultSkillsTests {
    @Test func keepsEachNameOnce() {
        #expect(VaultSkills.cleaned(["  Figma ", "figma", "Samen  werken", "", String(repeating: "x", count: 121)]) == ["Figma", "Samen werken"])
    }

    @Test func knownSkillsMostUsedFirst() {
        let items = [
            VaultItem(id: "a", category: .projects, title: "A", skills: ["Swift", "Figma"]),
            VaultItem(id: "b", category: .projects, title: "B", skills: ["figma", "Scrum"]),
        ]
        #expect(VaultSkills.known(in: items) == ["Figma", "Scrum", "Swift"])
    }
}

struct VaultEvidenceFormTests {
    @Test func asksForEveryFieldOfTheForm() {
        var draft = VaultItemDraft(category: .internships)
        #expect(draft.missingFields == [.title, .organisation, .period, .description])
        draft.title = "Stage"
        draft.organisationName = "LiveWall"
        draft.startDate = VaultDay(year: 2025, month: 2, day: 1)
        draft.description = "Front-end"
        #expect(draft.missingFields.isEmpty)
        draft.category = .certificates
        #expect(draft.missingFields == [.period])
        draft.usesPeriod = true
        #expect(draft.missingFields.isEmpty)
    }

    @Test func aCertificateCanHaveAPeriod() {
        var draft = VaultItemDraft(category: .certificates)
        draft.title = "Scrum"
        draft.usesPeriod = true
        draft.startDate = VaultDay(year: 2025, month: 1, day: 6)
        draft.endDate = VaultDay(year: 2025, month: 3, day: 28)
        draft.issuedOn = VaultDay(year: 2025, month: 4, day: 1)
        let row = draft.row
        #expect(row["start_date"] as? String == "2025-01-06")
        #expect(row["end_date"] as? String == "2025-03-28")
        #expect(row["issued_on"] is NSNull)
        #expect(draft.period == "jan 2025 - mrt 2025")
        let item = VaultItem(id: "a", category: .certificates, title: "Scrum", startDate: draft.startDate, endDate: draft.endDate)
        #expect(VaultItemDraft(item: item).isPeriod)
    }
}

extension SupabaseVaultServiceTests {
    @Test func readsTheAccountFromTheToken() {
        let payload = Data(#"{"sub":"2B1A0C4E-8D3F-4A21-9C7E-5F6B8A9D0E12","aal":"aal2"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        #expect(SupabaseVaultService.userID(fromToken: "e30.\(payload).sig") == "2b1a0c4e-8d3f-4a21-9c7e-5f6b8a9d0e12")
        #expect(SupabaseVaultService.userID(fromToken: "nope") == nil)
    }

    @Test func readsCoverAndAylaConsent() throws {
        let json = """
        [{"id":"a","category":"projects","title":"App","is_current":false,"verification_status":"toVerify","source":"user",
          "created_at":"2026-11-12T10:00:00Z","updated_at":"2026-11-12T10:00:00Z","ayla_allowed_at":"2026-11-12T10:05:00Z",
          "vault_item_files":[{"id":"f","file_name":"omslag.jpeg","mime_type":"image/jpeg","storage_path":"u/a/f.jpeg","role":"cover"},
                              {"id":"g","file_name":"verslag.pdf","mime_type":"application/pdf","storage_path":"u/a/g.pdf"}]}]
        """
        let item = try #require(try JSONDecoder().decode([ItemRow].self, from: Data(json.utf8)).first?.item)
        #expect(item.files.map(\.role) == [.cover, .document])
        #expect(item.aylaAllowedAt != nil)
    }
}

enum VaultMigration {
    static func url(_ name: String) -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "shared/supabase/migrations/\(name)")
    }
}

struct VaultExampleFolderTests {
    @Test func theExampleFolderFollowsTheCategoryWhileItExists() {
        let folders = [
            VaultFolder(id: "p", name: "projecten", createdAt: .now),
            VaultFolder(id: "s", name: "Stage", createdAt: .now),
        ]
        #expect(VaultExampleFolders.folder(for: .projects, in: folders)?.id == "p")
        #expect(VaultExampleFolders.folder(for: .certificates, in: folders) == nil)
        #expect(VaultExampleFolders.folder(for: .internships, in: folders) == nil)
        #expect(VaultExampleFolders.folder(for: .internships, in: folders + [VaultFolder(id: "st", name: "Stages")])?.id == "st")
    }

    @Test func theMigrationMakesTheSameFolders() throws {
        let sql = try String(contentsOf: VaultMigration.url("20261112120000_vault_cover_example_folders_reverify.sql"), encoding: .utf8)
        for example in VaultExampleFolders.all {
            #expect(sql.contains("'\(example.name.replacingOccurrences(of: "'", with: "''"))', '\(example.color.rawValue)', '\(example.icon.rawValue)'"))
        }
    }

    @Test func anUndeployedFunctionIsNotSetUp() {
        let body = Data(#"{"code":"NOT_FOUND","message":"Requested function was not found"}"#.utf8)
        #expect(SupabaseVaultService.error(status: 404, body: body) == .notSetUp)
        #expect(SupabaseVaultService.error(status: 404, body: Data(#"{"code":"PGRST205"}"#.utf8)) == .missingColumn)
    }
}

struct VaultFolderLinkTests {
    @Test func anItemCanBeInSeveralFolders() throws {
        let json = """
        [{"id":"a","folder_id":"p","category":"projects","title":"App","is_current":false,"verification_status":"toVerify","source":"user",
          "created_at":"2026-11-12T10:00:00Z","updated_at":"2026-11-12T10:00:00Z",
          "vault_item_folders":[{"folder_id":"s"},{"folder_id":"p"}]},
         {"id":"b","folder_id":"p","category":"projects","title":"Oud","is_current":false,"verification_status":"toVerify","source":"user",
          "created_at":"2026-11-12T10:00:00Z","updated_at":"2026-11-12T10:00:00Z"}]
        """
        let items = try JSONDecoder().decode([ItemRow].self, from: Data(json.utf8)).compactMap(\.item)
        #expect(items.map(\.folderIDs) == [["p", "s"], ["p"]])
        var filter = VaultFilter()
        filter.shelf = .folder("s")
        let shown = filter.apply(to: items)
        #expect(shown.map(\.id) == ["a"])
    }

    @Test func theFirstFolderStaysInFolderIDForOlderClients() {
        var draft = VaultItemDraft(category: .projects, folderIDs: ["p", "s"])
        draft.title = "App"
        #expect(draft.row["folder_id"] as? String == "p")
        draft.folderIDs = []
        #expect(draft.row["folder_id"] is NSNull)
    }

    @Test func aMissingRelationIsNotMigratedYet() {
        #expect(SupabaseVaultService.error(status: 400, body: Data(#"{"code":"PGRST200"}"#.utf8)) == .missingColumn)
    }
}
