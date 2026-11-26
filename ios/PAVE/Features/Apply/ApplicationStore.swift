import Foundation
import PAVECore

/// Keeps drafts on this device, one file per vacancy, encrypted while the iPhone is locked. `ApplicationDraftSyncer`
/// keeps them the same as the account's, so a draft goes on on another device.
struct ApplicationStore {
    private let folder: URL
    private let defaults: UserDefaults
    private static let deletedKey = "applications.deleted"
    private static let ownerKey = "applications.account"

    init(folder: URL = URL.applicationSupportDirectory.appending(path: "Applications", directoryHint: .isDirectory), defaults: UserDefaults = .standard) {
        self.folder = folder
        self.defaults = defaults
    }

    func load(_ vacancyID: String) -> ApplicationDraft? {
        guard let data = try? Data(contentsOf: file(vacancyID)) else { return nil }
        return try? JSONDecoder().decode(ApplicationDraft.self, from: data)
    }

    func save(_ draft: ApplicationDraft) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(draft) else { return }
        try? data.write(to: file(draft.id), options: [.atomic, .completeFileProtection])
        forgetDeletions([draft.id])
    }

    /// Deleted by the user: remembered, so the account and the other devices drop it too.
    func delete(_ vacancyID: String) {
        remove(vacancyID)
        var deleted = defaults.dictionary(forKey: Self.deletedKey) as? [String: Double] ?? [:]
        deleted[vacancyID] = Date.now.timeIntervalSince1970
        defaults.set(deleted, forKey: Self.deletedKey)
    }

    /// Removed because another device deleted it: nothing to pass on.
    func remove(_ vacancyID: String) {
        try? FileManager.default.removeItem(at: file(vacancyID))
    }

    /// What was deleted on this device and when, until the account knows.
    func deletions() -> [String: Date] {
        (defaults.dictionary(forKey: Self.deletedKey) as? [String: Double] ?? [:]).mapValues(Date.init(timeIntervalSince1970:))
    }

    func forgetDeletions(_ ids: [String]) {
        guard !ids.isEmpty, var deleted = defaults.dictionary(forKey: Self.deletedKey) as? [String: Double] else { return }
        ids.forEach { deleted[$0] = nil }
        defaults.set(deleted, forKey: Self.deletedKey)
    }

    /// The applications on a device go to the first account that syncs them, and never to another one after that:
    /// someone else signing in on this device does not get them in their account.
    func claim(for accountID: String) -> Bool {
        if let owner = defaults.string(forKey: Self.ownerKey) { return owner == accountID }
        defaults.set(accountID, forKey: Self.ownerKey)
        return true
    }

    /// Every application kept on this device, the one changed last first.
    func all() -> [ApplicationDraft] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(ApplicationDraft.self, from: Data(contentsOf: $0)) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func file(_ vacancyID: String) -> URL {
        let safe = vacancyID.map { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" ? $0 : "_" }
        return folder.appending(path: String(safe) + ".json")
    }
}
