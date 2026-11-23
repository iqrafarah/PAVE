import Foundation
import Observation
import SwiftUI
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
    /// "Bewijs toevoegen" closed before it was saved: for half a minute it comes back as it was, in case that was by
    /// accident. Only in memory, on this device.
    @ObservationIgnored private var addDraft: (flow: VaultAddEvidenceModel, until: Date)?
    static let draftLifetime: TimeInterval = 30
    /// Files already fetched in this session, so a thumbnail or preview does not download twice.
    @ObservationIgnored private var fileCache: [String: Data] = [:]
    @ObservationIgnored private var lookCache: [String: VaultLogoLook] = [:]
    /// Folder colours and icons kept on this device while the database has no columns for them yet.
    @ObservationIgnored private let localStyles = UserDefaults.standard
    private static let localStylesKey = "vaultFolderStyles"
    /// The folder order kept on this device while the database has no column for it yet.
    private static let localOrderKey = "vaultFolderOrder"
    private static let localItemOrderKey = "vaultItemOrder"
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
    /// The archive: out of the vault, kept until it is put back or deleted.
    var archived: [VaultItem] { contents.archived }
    var canArchive: Bool { contents.canArchive }

    /// Archives evidence or puts it back.
    @discardableResult
    func setArchived(_ isArchived: Bool, _ item: VaultItem) async -> Bool {
        await perform { try await $0.setArchived(isArchived, itemID: item.id) }
    }
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
            contents = ordered(try await service.contents())
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
        if let refreshed = try? await service.contents() { contents = ordered(refreshed) }
    }

    /// The order kept on this device, while the database cannot keep it; new folders after the others.
    private func ordered(_ loaded: VaultContents) -> VaultContents {
        var result = loaded
        if let itemOrder = localStyles.stringArray(forKey: Self.localItemOrderKey) {
            for index in result.items.indices {
                result.items[index].position = itemOrder.firstIndex(of: result.items[index].id)
            }
        }
        if let order = localStyles.stringArray(forKey: Self.localOrderKey) {
            let place = { (folder: VaultFolder) in order.firstIndex(of: folder.id) ?? Int.max }
            result.folders = result.folders.enumerated()
                .sorted { (place($0.element), $0.offset) < (place($1.element), $1.offset) }
                .map(\.element)
        }
        // Pinned folders first, each group in its own order, as on the web.
        result.folders = result.folders.filter(\.isPinned) + result.folders.filter { !$0.isPinned }
        return result
    }

    /// "Vastzetten": the folder moves to the front at once; the server keeps it there on every device.
    func setPinned(_ pinned: Bool, folder: VaultFolder) async {
        guard let index = contents.folders.firstIndex(where: { $0.id == folder.id }) else { return }
        contents.folders[index].pinnedAt = pinned ? .now : nil
        contents = ordered(contents)
        if await perform({ try await $0.setFolderPinned(pinned, folderID: folder.id) }) {
            AccessibilityNotification.Announcement(pinned ? VaultMessages.folderPinned(folder.name) : VaultMessages.folderUnpinned(folder.name)).post()
        }
    }

    // MARK: Moving

    /// Dragged onto a folder: into that folder, and out of the folder it was dragged from. From the whole vault it only
    /// goes in, and its other folders stay.
    func move(_ item: VaultItem, to folder: VaultFolder, from sourceFolderID: String?) async {
        var ids = item.folderIDs.filter { $0 != sourceFolderID }
        if !ids.contains(folder.id) { ids.append(folder.id) }
        guard ids != item.folderIDs else { return }
        await perform { try await $0.setFolders(ids, itemID: item.id) }
    }

    /// "Eigen volgorde": the cards that were on screen in the order they were dragged into. Cards that were not on screen
    /// (in another folder, or filtered out) keep their places around them.
    func setItemOrder(_ visible: [String]) async {
        var custom = VaultFilter()
        custom.order = .custom
        var all = custom.apply(to: items).map(\.id)
        let slots = all.indices.filter { visible.contains(all[$0]) }
        for (slot, id) in zip(slots, visible) { all[slot] = id }
        for index in contents.items.indices {
            contents.items[index].position = all.firstIndex(of: contents.items[index].id)
        }
        guard let service else { return }
        do {
            try await service.setItemOrder(all)
            localStyles.removeObject(forKey: Self.localItemOrderKey)
        } catch VaultError.missingColumn {
            localStyles.set(all, forKey: Self.localItemOrderKey)
        } catch {
            fail(error)
            await load()
        }
    }

    /// One folder takes the place of another, for VoiceOver's "Naar voren" and "Naar achteren".
    func moveFolder(_ id: String, onto targetID: String) async {
        var order = folders.map(\.id)
        guard let from = order.firstIndex(of: id), let to = order.firstIndex(of: targetID), from != to else { return }
        order.remove(at: from)
        order.insert(id, at: to)
        await setFolderOrder(order)
    }

    /// The folders in this order at once, as they were dragged. The order is saved for every device, or on this device
    /// until the database has a place for it.
    func setFolderOrder(_ order: [String]) async {
        let reordered = order.compactMap { id in folders.first { $0.id == id } } + folders.filter { !order.contains($0.id) }
        guard reordered.map(\.id) != folders.map(\.id) else { return }
        contents.folders = reordered
        let ids = reordered.map(\.id)
        guard let service else { return }
        do {
            try await service.setFolderOrder(ids)
            localStyles.removeObject(forKey: Self.localOrderKey)
        } catch VaultError.missingColumn {
            localStyles.set(ids, forKey: Self.localOrderKey)
        } catch {
            fail(error)
            await load()
        }
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

    // MARK: Uit je wallet (demo)

    /// The credentials in this account's demo wallet.
    func walletCredentials() async throws -> [VaultWalletCredential] {
        guard let service else { throw VaultError.unavailable }
        return try await service.walletCredentials()
    }

    /// Puts the chosen credentials in the vault, confirmed, with the issuer's logo when there is one, each in the folder
    /// of its kind when you have one, and in the folder you started from. Returns the new items.
    func importFromWallet(_ credentials: [VaultWalletCredential], folderID: String?) async throws -> [String] {
        guard let service else { throw VaultError.unavailable }
        let made = try await service.importFromWallet(credentials.map(\.id))
        let itemIDs = credentials.compactMap { made[$0.id] }
        for credential in credentials {
            guard let logo = credential.logo, let itemID = made[credential.id] else { continue }
            try? await service.attach(VaultUpload(data: logo.data, fileName: logo.fileName, mimeType: logo.mimeType, role: .logo), to: itemID)
        }
        if let refreshed = try? await service.contents() { contents = ordered(refreshed) }
        for item in items where itemIDs.contains(item.id) {
            var folderIDs: [String] = []
            for id in [folderID, VaultExampleFolders.folder(for: item.category, in: folders)?.id].compactMap({ $0 }) where !folderIDs.contains(id) {
                folderIDs.append(id)
            }
            if !folderIDs.isEmpty { try? await service.setFolders(folderIDs, itemID: item.id) }
        }
        await load()
        return itemIDs
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

    func keepDraft(_ flow: VaultAddEvidenceModel, now: Date = .now) {
        guard flow.hasChanges, !flow.isSaving else { return }
        addDraft = (flow, now.addingTimeInterval(Self.draftLifetime))
    }

    /// The draft closed less than half a minute ago, once; after that it is gone.
    func takeDraft(now: Date = .now) -> VaultAddEvidenceModel? {
        defer { addDraft = nil }
        guard let addDraft, addDraft.until > now else { return nil }
        addDraft.flow.isResumed = true
        return addDraft.flow
    }

    /// Ayla may propose a skill that is elsewhere in the vault again, so this evidence counts for it too.
    func suggestSkills(for draft: VaultItemDraft, material: VaultSkillsMaterial, chosen: [String]) async throws -> [VaultSkillSuggestion] {
        guard let service else { throw VaultError.unavailable }
        return try await service.suggestSkills(for: draft, material: material, existing: chosen, known: VaultSkills.known(in: items))
    }

    func proposeEvidence(from documents: [VaultEvidenceDocument]) async throws -> [VaultEvidenceProposal] {
        guard let service else { throw VaultError.unavailable }
        return try await service.proposeEvidence(from: documents, folders: folders.map(\.name), known: VaultSkills.known(in: items))
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

    func validationOrganizations() async throws -> [VaultValidationOrganization] {
        guard let service else { throw VaultError.notSetUp }
        return try await service.validationOrganizations()
    }

    func validationLocations(organizationID: String) async throws -> [VaultValidationLocation] {
        guard let service else { throw VaultError.notSetUp }
        return try await service.validationLocations(organizationID: organizationID)
    }

    func validationDepartments(locationID: String) async throws -> [VaultValidationDepartment] {
        guard let service else { throw VaultError.notSetUp }
        return try await service.validationDepartments(locationID: locationID)
    }

    func validationContacts(departmentID: String) async throws -> [VaultValidationContact] {
        guard let service else { throw VaultError.notSetUp }
        return try await service.validationContacts(departmentID: departmentID)
    }

    func requestValidation(
        for item: VaultItem,
        organizationID: String,
        locationID: String,
        departmentID: String,
        contactID: String,
        message: String?
    ) async -> String? {
        guard let service else {
            problem = VaultMessages.requestNotActive
            return problem
        }
        do {
            try await service.requestValidation(
                itemID: item.id,
                organizationID: organizationID,
                locationID: locationID,
                departmentID: departmentID,
                contactID: contactID,
                message: message
            )
            problem = nil
            PaveHaptics.success()
            // So the item shows "In afwachting" straight away.
            await load()
            return nil
        } catch {
            let message = VaultMessages.message(for: VaultError(error))
            problem = message
            PaveHaptics.error()
            return message
        }
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
