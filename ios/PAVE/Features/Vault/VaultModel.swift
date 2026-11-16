import Foundation
import Observation
import PAVECore

/// Your vault as the app shows it. Everything comes from and goes to Supabase; there is nothing stored on the phone.
@Observable
final class VaultModel {
    enum State: Equatable {
        case loading
        case ready
        /// Signed in with the demo account: there is no vault.
        case unavailable
        case failed(VaultError)
    }

    private(set) var state = State.loading
    private(set) var contents = VaultContents()
    /// Saving, moving or deleting did not work; the screen shows it.
    var problem: String?
    /// An item to open in the vault, for example from Ayla's "Open Eindstage".
    var itemToOpen: String?

    private let service: (any VaultService)?
    /// Files already fetched in this session, so a thumbnail or preview does not download twice.
    @ObservationIgnored private var fileCache: [String: Data] = [:]
    @ObservationIgnored private var lookCache: [String: VaultLogoLook] = [:]
    /// Folder colours and icons kept on this device while the database has no columns for them yet.
    @ObservationIgnored private let localStyles = UserDefaults.standard
    private static let localStylesKey = "vaultFolderStyles"
    /// The example folders were made on this phone once; deleting one later must not bring it back.
    static let exampleFoldersKey = "vaultExampleFoldersMade"

    init(service: (any VaultService)?) {
        self.service = service
        if service == nil { state = .unavailable }
    }

    #if DEBUG
    /// For previews: a vault that is already loaded.
    init(previewContents: VaultContents) {
        service = nil
        contents = previewContents
        state = .ready
    }
    #endif

    var items: [VaultItem] { contents.items }
    var folders: [VaultFolder] { contents.folders }

    func count(in shelf: VaultShelf) -> Int {
        switch shelf {
        case .all: items.count
        case .category(let category): items.count { $0.category == category }
        case .folder(let id): items.count { $0.folderIDs.contains(id) }
        }
    }

    func folder(_ id: String?) -> VaultFolder? {
        folders.first { $0.id == id }
    }

    /// The colour and icon from the database; otherwise what this device remembers; otherwise green with a folder.
    func style(of folder: VaultFolder) -> (color: VaultFolderColor, icon: VaultFolderIcon) {
        let local = (localStyles.dictionary(forKey: Self.localStylesKey)?[folder.id] as? String)?.split(separator: "|")
        let localColor = local?.first.flatMap { VaultFolderColor(rawValue: String($0)) }
        let localIcon = local?.last.flatMap { VaultFolderIcon(rawValue: String($0)) }
        return (folder.color ?? localColor ?? .green, folder.icon ?? localIcon ?? .folder)
    }

    func isFolderNameTaken(_ name: String, except id: String? = nil) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return folders.contains { $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    /// Shows the spinner only the first time; after that the list stays while it refreshes.
    func load() async {
        guard let service else { return }
        do {
            contents = try await service.contents()
            state = .ready
        } catch {
            if state != .ready { state = .failed(VaultError(error)) }
        }
        await makeExampleFoldersIfNeeded()
    }

    /// Until the migration makes them on the server: an account without any folder gets the four example folders once,
    /// and its items go into the folder of their kind, as they showed before.
    private func makeExampleFoldersIfNeeded() async {
        guard let service, state == .ready, contents.folders.isEmpty, !localStyles.bool(forKey: Self.exampleFoldersKey) else { return }
        localStyles.set(true, forKey: Self.exampleFoldersKey)
        var made: [VaultFolder] = []
        for example in VaultExampleFolders.all {
            if let (folder, _) = try? await service.createFolder(named: example.name, color: example.color, icon: example.icon) {
                made.append(folder)
            }
        }
        guard !made.isEmpty else { return }
        for item in contents.items where item.folderIDs.isEmpty {
            if let folder = VaultExampleFolders.folder(for: item.category, in: made) {
                try? await service.setFolders([folder.id], itemID: item.id)
            }
        }
        if let refreshed = try? await service.contents() { contents = refreshed }
    }

    func retry() async {
        state = .loading
        await load()
    }

    @discardableResult
    func save(_ draft: VaultItemDraft, itemID: String?) async -> Bool {
        await perform { service in
            if let itemID {
                try await service.update(draft, itemID: itemID)
            } else {
                try await service.add(draft)
            }
        }
    }

    // MARK: Files

    func cover(of item: VaultItem) -> VaultItem.File? {
        item.files.first { $0.role == .cover }
    }

    func logo(of item: VaultItem) -> VaultItem.File? {
        item.files.first { $0.role == .logo }
    }

    func documents(of item: VaultItem) -> [VaultItem.File] {
        item.files.filter { $0.role == .document }
    }

    /// The bytes of a file, from this session's cache or from the private bucket; nil when it cannot be fetched now.
    func data(of file: VaultItem.File) async -> Data? {
        if let cached = fileCache[file.id] { return cached }
        guard let service, let data = try? await service.fileData(file) else { return nil }
        fileCache[file.id] = data
        return data
    }

    /// The logo as it looks on a card: the image for the avatar and the tint for the band.
    func look(of logo: VaultItem.File) async -> VaultLogoLook? {
        if let cached = lookCache[logo.id] { return cached }
        guard let data = await data(of: logo), let look = await VaultLogoLook.make(from: data) else { return nil }
        lookCache[logo.id] = look
        return look
    }

    // MARK: Bewijs toevoegen

    /// The steps of adding evidence report their own errors, so these throw instead of setting `problem`.
    func addItem(_ draft: VaultItemDraft) async throws -> String {
        guard let service else { throw VaultError.unavailable }
        return try await service.add(draft)
    }

    func attach(_ upload: VaultUpload, to itemID: String) async throws {
        guard let service else { throw VaultError.unavailable }
        try await service.attach(upload, to: itemID)
    }

    func addSkills(_ names: [String], to itemID: String) async throws {
        guard let service else { throw VaultError.unavailable }
        try await service.addSkills(names, to: itemID)
    }

    func setAylaAllowed(_ allowed: Bool, itemID: String) async throws {
        guard let service else { throw VaultError.unavailable }
        try await service.setAylaAllowed(allowed, itemID: itemID)
    }

    func updateItem(_ draft: VaultItemDraft, itemID: String) async throws {
        guard let service else { throw VaultError.unavailable }
        try await service.update(draft, itemID: itemID)
    }

    func removeFile(_ file: VaultItem.File) async throws {
        guard let service else { throw VaultError.unavailable }
        try await service.removeFile(file)
        fileCache[file.id] = nil
    }

    func removeSkills(_ names: [String], from itemID: String) async throws {
        guard let service else { throw VaultError.unavailable }
        try await service.removeSkills(names, from: itemID)
    }

    func suggestSkills(for draft: VaultItemDraft, material: VaultSkillsMaterial, existing: [String]) async throws -> [VaultSkillSuggestion] {
        guard let service else { throw VaultError.unavailable }
        return try await service.suggestSkills(for: draft, material: material, existing: existing)
    }

    /// The folders the item is in, in the order of the folder row.
    func folders(of item: VaultItem) -> [VaultFolder] {
        folders.filter { item.folderIDs.contains($0.id) }
    }

    /// Puts the item in this folder as well, or takes it out of it; its other folders stay.
    func toggle(_ folder: VaultFolder, for item: VaultItem) async {
        var ids = item.folderIDs
        if let index = ids.firstIndex(of: folder.id) { ids.remove(at: index) } else { ids.append(folder.id) }
        await perform { try await $0.setFolders(ids, itemID: item.id) }
    }

    func delete(_ item: VaultItem) async {
        await perform { try await $0.delete(item) }
    }

    func createFolder(named name: String, color: VaultFolderColor, icon: VaultFolderIcon) async -> VaultFolder? {
        guard let service else { return nil }
        do {
            let (folder, styleSaved) = try await service.createFolder(named: name, color: color, icon: icon)
            if !styleSaved { rememberLocally(color: color, icon: icon, folderID: folder.id) }
            contents.folders.append(folder)
            PaveHaptics.success()
            return folder
        } catch {
            fail(error)
            return nil
        }
    }

    @discardableResult
    func updateFolder(_ folder: VaultFolder, name: String, color: VaultFolderColor, icon: VaultFolderIcon) async -> Bool {
        await perform { service in
            let styleSaved = try await service.updateFolder(id: folder.id, name: name, color: color, icon: icon)
            if !styleSaved { self.rememberLocally(color: color, icon: icon, folderID: folder.id) }
        }
    }

    private func rememberLocally(color: VaultFolderColor, icon: VaultFolderIcon, folderID: String) {
        var styles = localStyles.dictionary(forKey: Self.localStylesKey) ?? [:]
        styles[folderID] = "\(color.rawValue)|\(icon.rawValue)"
        localStyles.set(styles, forKey: Self.localStylesKey)
    }

    func deleteFolder(_ folder: VaultFolder) async {
        await perform { try await $0.deleteFolder(id: folder.id) }
    }

    /// Runs a change and then reads the vault again, so counts and folders are always what the server has.
    @discardableResult
    private func perform(_ change: (any VaultService) async throws -> Void) async -> Bool {
        guard let service else { return false }
        do {
            try await change(service)
            PaveHaptics.success()
            await load()
            return true
        } catch {
            fail(error)
            return false
        }
    }

    private func fail(_ error: any Error) {
        PaveHaptics.error()
        problem = VaultMessages.message(for: VaultError(error))
    }
}
