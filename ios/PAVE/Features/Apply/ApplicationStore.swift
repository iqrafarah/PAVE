import Foundation
import PAVECore

/// Keeps drafts on this device, one file per vacancy, encrypted while the iPhone is locked, in a folder of the account
/// that is signed in: someone else signing in on this iPhone never sees them. `ApplicationDraftSyncer` keeps them the
/// same as the account's in Supabase, so a draft goes on on another device.
struct ApplicationStore {
    private let folder: URL
    private let defaults: UserDefaults
    private let deletedKey: String
    private let ownerKey: String
    private static let root = URL.applicationSupportDirectory.appending(path: "Applications", directoryHint: .isDirectory)
    /// Before the folders per account: one folder for the device, and the account that synced it first.
    private static let legacyOwnerKey = "applications.account"

    /// This account's applications; with `folder`, those in that folder (tests).
    init(folder: URL? = nil, defaults: UserDefaults = .standard) {
        if let folder {
            self.folder = folder
            deletedKey = "applications.deleted"
            ownerKey = Self.legacyOwnerKey
        } else {
            Self.moveLegacyFiles(defaults: defaults)
            self.folder = Self.root.appending(path: PaveAccount.folderName(in: defaults), directoryHint: .isDirectory)
            deletedKey = PaveAccount.key("applications.deleted", in: defaults)
            ownerKey = PaveAccount.key(Self.legacyOwnerKey, in: defaults)
        }
        self.defaults = defaults
    }

    /// The drafts from before the folders per account go to the account that synced them; drafts no account ever
    /// synced go to a folder nobody reads, so they are not shown to whoever signs in next.
    private static func moveLegacyFiles(defaults: UserDefaults) {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        let drafts = files.filter { $0.pathExtension == "json" }
        guard !drafts.isEmpty else { return }
        let owner = defaults.string(forKey: legacyOwnerKey).map { String($0.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" }) } ?? "unclaimed"
        let target = root.appending(path: owner, directoryHint: .isDirectory)
        try? manager.createDirectory(at: target, withIntermediateDirectories: true)
        for file in drafts {
            let destination = target.appending(path: file.lastPathComponent)
            try? manager.removeItem(at: destination)
            try? manager.moveItem(at: file, to: destination)
        }
        if let deleted = defaults.dictionary(forKey: "applications.deleted"), owner != "unclaimed" {
            defaults.set(deleted, forKey: "applications.deleted.\(owner)")
        }
        defaults.removeObject(forKey: "applications.deleted")
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
        var deleted = defaults.dictionary(forKey: deletedKey) as? [String: Double] ?? [:]
        deleted[vacancyID] = Date.now.timeIntervalSince1970
        defaults.set(deleted, forKey: deletedKey)
    }

    /// Removed because another device deleted it: nothing to pass on.
    func remove(_ vacancyID: String) {
        try? FileManager.default.removeItem(at: file(vacancyID))
    }

    /// What was deleted on this device and when, until the account knows.
    func deletions() -> [String: Date] {
        (defaults.dictionary(forKey: deletedKey) as? [String: Double] ?? [:]).mapValues(Date.init(timeIntervalSince1970:))
    }

    func forgetDeletions(_ ids: [String]) {
        guard !ids.isEmpty, var deleted = defaults.dictionary(forKey: deletedKey) as? [String: Double] else { return }
        ids.forEach { deleted[$0] = nil }
        defaults.set(deleted, forKey: deletedKey)
    }

    /// The applications on a device go to the first account that syncs them, and never to another one after that:
    /// someone else signing in on this device does not get them in their account.
    func claim(for accountID: String) -> Bool {
        if let owner = defaults.string(forKey: ownerKey) { return owner == accountID }
        defaults.set(accountID, forKey: ownerKey)
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
