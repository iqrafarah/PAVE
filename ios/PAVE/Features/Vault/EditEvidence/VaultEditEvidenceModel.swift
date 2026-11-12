import Foundation
import Observation
import PAVECore

/// Changing evidence that is already in the vault: the details, the cover, the documents, the skills and Ayla's
/// permission. Every item can be changed; a confirmed one then has to be confirmed again (the database sets it back).
/// A failed save tries only what is still missing the next time.
@Observable
final class VaultEditEvidenceModel {
    private enum Part: Hashable { case details, removed(String), cover, logo, document(Int), skills, ayla }

    let item: VaultItem
    var draft: VaultItemDraft
    var wantsCover: Bool
    private(set) var keptCover: VaultItem.File?
    private(set) var newCover: VaultUpload?
    private(set) var keptLogo: VaultItem.File?
    private(set) var newLogo: VaultUpload?
    private(set) var keptDocuments: [VaultItem.File]
    private(set) var newDocuments: [VaultUpload] = []
    var skills: [String]
    var allowsAyla: Bool
    let ayla: VaultAylaSkills
    var problem: String?
    private(set) var isSaving = false
    private(set) var coverWaits = false

    private let vault: VaultModel
    private let originalDraft: VaultItemDraft
    private let originalCover: VaultItem.File?
    private let originalLogo: VaultItem.File?
    private let originalDocuments: [VaultItem.File]
    private let originalSkills: [String]
    private let originalAyla: Bool
    private var savedParts: Set<Part> = []

    init(vault: VaultModel, item: VaultItem) {
        self.vault = vault
        self.item = item
        ayla = VaultAylaSkills(vault: vault)
        let draft = VaultItemDraft(item: item)
        self.draft = draft
        originalDraft = draft
        let cover = vault.cover(of: item)
        originalCover = cover
        keptCover = cover
        wantsCover = cover != nil
        let logo = vault.logo(of: item)
        originalLogo = logo
        keptLogo = logo
        let documents = vault.documents(of: item)
        originalDocuments = documents
        keptDocuments = documents
        skills = item.skills
        originalSkills = item.skills
        allowsAyla = item.aylaAllowedAt != nil
        originalAyla = item.aylaAllowedAt != nil
    }

    var folders: [VaultFolder] { vault.folders }
    var knownSkills: [String] { VaultSkills.known(in: vault.items) }
    var hasFile: Bool { !keptDocuments.isEmpty || !newDocuments.isEmpty }
    var canAddDocument: Bool { keptDocuments.count + newDocuments.count < VaultAddEvidenceModel.maximumDocuments }

    /// What the cover shows now: a new photo, or the one the item had.
    var cover: VaultThumbnail.Source? {
        if let newCover { return .upload(newCover) }
        return keptCover.map { .file($0) }
    }

    var logo: VaultThumbnail.Source? {
        if let newLogo { return .upload(newLogo) }
        return keptLogo.map { .file($0) }
    }

    private var removedFiles: [VaultItem.File] {
        var removed = originalDocuments.filter { kept in !keptDocuments.contains(kept) }
        if let originalCover, keptCover == nil || !wantsCover { removed.append(originalCover) }
        if let originalLogo, keptLogo == nil { removed.append(originalLogo) }
        return removed
    }

    private var addedSkills: [String] { skills.filter { name in !originalSkills.contains { $0.caseInsensitiveCompare(name) == .orderedSame } } }
    private var removedSkills: [String] { originalSkills.filter { name in !skills.contains { $0.caseInsensitiveCompare(name) == .orderedSame } } }

    var detailsChanged: Bool { draft != originalDraft }
    var filesChanged: Bool { !removedFiles.isEmpty || !newDocuments.isEmpty || (wantsCover && newCover != nil) || newLogo != nil }
    var hasChanges: Bool {
        detailsChanged || filesChanged || !addedSkills.isEmpty || !removedSkills.isEmpty || allowsAyla != originalAyla
    }

    /// Saving takes the "confirmed" away; the user is asked first.
    var needsReconfirmation: Bool { item.changeNeedsReconfirmation && (detailsChanged || filesChanged) }

    // MARK: Files

    func pick(_ result: Result<VaultUpload, VaultUpload.Problem>) {
        switch result {
        case .success(let upload) where upload.role == .cover:
            // One cover per item: the old one goes when you save.
            newCover = upload
            keptCover = nil
            problem = nil
        case .success(let upload) where upload.role == .logo:
            newLogo = upload
            keptLogo = nil
            problem = nil
        case .success(let upload):
            guard canAddDocument, !newDocuments.contains(upload) else { return }
            newDocuments.append(upload)
            problem = nil
        case .failure(let failure):
            problem = VaultMessages.upload(failure)
            PaveHaptics.error()
        }
    }

    func removeCover() {
        newCover = nil
        keptCover = nil
    }

    func removeLogo() {
        newLogo = nil
        keptLogo = nil
    }

    func remove(_ file: VaultItem.File) {
        keptDocuments.removeAll { $0 == file }
    }

    func remove(_ upload: VaultUpload) {
        newDocuments.removeAll { $0 == upload }
    }

    // MARK: Saving

    func save() async -> Bool {
        guard !isSaving else { return false }
        if let firstProblem = draft.problem {
            problem = VaultMessages.problem(firstProblem)
            PaveHaptics.error()
            return false
        }
        if wantsCover, keptCover == nil, newCover == nil {
            problem = VaultMessages.coverMissing
            PaveHaptics.error()
            return false
        }
        problem = nil
        isSaving = true
        defer { isSaving = false }
        SupabaseVaultService.lastFailure = nil
        do {
            if detailsChanged, !savedParts.contains(.details) {
                try await vault.updateItem(draft, itemID: item.id)
                savedParts.insert(.details)
            }
            for file in removedFiles where !savedParts.contains(.removed(file.id)) {
                try await vault.removeFile(file)
                savedParts.insert(.removed(file.id))
            }
            if wantsCover, let newCover, !savedParts.contains(.cover) {
                do {
                    try await vault.attach(newCover, to: item.id)
                } catch VaultError.missingColumn {
                    coverWaits = true
                }
                savedParts.insert(.cover)
            }
            if let newLogo, !savedParts.contains(.logo) {
                do {
                    try await vault.attach(newLogo, to: item.id)
                } catch VaultError.missingColumn {
                    coverWaits = true
                }
                savedParts.insert(.logo)
            }
            for (index, document) in newDocuments.enumerated() where !savedParts.contains(.document(index)) {
                try await vault.attach(document, to: item.id)
                savedParts.insert(.document(index))
            }
            if !savedParts.contains(.skills) {
                try await vault.addSkills(addedSkills, to: item.id)
                try await vault.removeSkills(removedSkills, from: item.id)
                savedParts.insert(.skills)
            }
            if allowsAyla != originalAyla, !savedParts.contains(.ayla) {
                try await vault.setAylaAllowed(allowsAyla, itemID: item.id)
                savedParts.insert(.ayla)
            }
            await vault.load()
            PaveHaptics.success()
            return true
        } catch {
            problem = VaultMessages.withDetail(VaultMessages.message(for: VaultError(error)))
            PaveHaptics.error()
            await vault.load()
            return false
        }
    }
}
