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

    private let service: (any VaultService)?
    /// Folder colours and icons kept on this device while the database has no columns for them yet.
    @ObservationIgnored private let localStyles = UserDefaults.standard
    private static let localStylesKey = "vaultFolderStyles"

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
        case .folder(let id): items.count { $0.folderID == id }
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

    func move(_ item: VaultItem, to folderID: String?) async {
        await perform { try await $0.move(itemID: item.id, to: folderID) }
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
