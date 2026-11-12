import Foundation
import Observation
import PAVECore

/// Adding evidence in four steps, as in Figma: Basis (a file or none, then the details), Documenten (a cover),
/// Vaardigheden and Toestemming. Nothing is saved until the skills step; after that the item exists and only what is
/// still missing is tried again.
@Observable
final class VaultAddEvidenceModel {
    enum Page: Int, Comparable {
        case source
        case details
        case documents
        case skills
        case done

        static func < (lhs: Page, rhs: Page) -> Bool { lhs.rawValue < rhs.rawValue }

        /// The number in the stepper, from zero: the file and the details are both "Basis".
        var step: Int {
            switch self {
            case .source, .details: 0
            case .documents: 1
            case .skills: 2
            case .done: 3
            }
        }
    }

    private enum Part: Hashable { case document(Int), cover, logo, skills }

    /// Enough for a report, a certificate and a few photos, without turning the vault into file storage.
    static let maximumDocuments = 5

    private(set) var page = Page.source
    /// Which way the pages slide.
    private(set) var movesForward = true
    var draft: VaultItemDraft
    private(set) var documents: [VaultUpload] = []
    var wantsCover = false
    private(set) var cover: VaultUpload?
    /// The image in the round avatar on the card.
    private(set) var logo: VaultUpload?
    var skills: [String] = []
    let ayla: VaultAylaSkills
    var allowsAyla = false
    /// Shown above the buttons: a file that cannot be used, a missing cover or a failed save.
    var problem: String?
    /// The empty fields are marked only after Volgende was tapped once.
    private(set) var showsMissing = false
    private(set) var isSaving = false
    private(set) var savedItemID: String?
    /// The database has no cover column yet: the item was saved without its cover.
    private(set) var coverWaits = false

    private var savedParts: Set<Part> = []
    private let initialDraft: VaultItemDraft
    private let vault: VaultModel
    /// New evidence goes in the folder of its kind (a project in Projecten) and in the folder you add it from. The
    /// folder of the kind follows when you change the kind, until you choose folders yourself.
    private var folderFollowsCategory = true
    private var kindFolderID: String?

    init(vault: VaultModel, category: VaultCategory, folderID: String?) {
        self.vault = vault
        ayla = VaultAylaSkills(vault: vault)
        let kindFolder = VaultExampleFolders.folder(for: category, in: vault.folders)?.id
        kindFolderID = kindFolder
        var folderIDs = [String]()
        for id in [folderID, kindFolder].compactMap({ $0 }) where !folderIDs.contains(id) { folderIDs.append(id) }
        initialDraft = VaultItemDraft(category: category, folderIDs: folderIDs)
        draft = initialDraft
    }

    var folders: [VaultFolder] { vault.folders }

    func folderChosen() {
        folderFollowsCategory = false
    }

    func categoryChanged() {
        guard folderFollowsCategory else { return }
        let newKindFolder = VaultExampleFolders.folder(for: draft.category, in: vault.folders)?.id
        if let kindFolderID { draft.folderIDs.removeAll { $0 == kindFolderID } }
        if let newKindFolder, !draft.folderIDs.contains(newKindFolder) { draft.folderIDs.append(newKindFolder) }
        kindFolderID = newKindFolder
    }

    var hasChanges: Bool {
        savedItemID == nil && (draft != initialDraft || !documents.isEmpty || cover != nil || logo != nil || !skills.isEmpty)
    }

    /// Back is gone once the item is saved: changing the details then would not reach the vault.
    var canGoBack: Bool { page > .source && page < .done && savedItemID == nil }

    var missingFields: [VaultItemDraft.Field] { showsMissing ? draft.missingFields : [] }

    var knownSkills: [String] { VaultSkills.known(in: vault.items) }

    var hasFile: Bool { !documents.isEmpty }

    var canAddDocument: Bool { documents.count < Self.maximumDocuments }

    // MARK: Files

    func pick(_ result: Result<VaultUpload, VaultUpload.Problem>) {
        switch result {
        case .success(let upload) where upload.role == .cover:
            cover = upload
            problem = nil
        case .success(let upload) where upload.role == .logo:
            logo = upload
            problem = nil
        case .success(let upload):
            guard canAddDocument, !documents.contains(upload) else { return }
            documents.append(upload)
            if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
                draft.title = String(upload.suggestedTitle.prefix(VaultItemDraft.maximumTitleLength))
            }
            problem = nil
        case .failure(let failure):
            problem = VaultMessages.upload(failure)
            PaveHaptics.error()
        }
    }

    func remove(_ upload: VaultUpload) {
        documents.removeAll { $0 == upload }
    }

    func removeCover() { cover = nil }

    func removeLogo() { logo = nil }

    // MARK: Skills

    func isChosen(_ skill: String) -> Bool {
        skills.contains { $0.caseInsensitiveCompare(skill) == .orderedSame }
    }

    func toggle(_ skill: String) {
        if isChosen(skill) {
            skills.removeAll { $0.caseInsensitiveCompare(skill) == .orderedSame }
        } else {
            skills = VaultSkills.cleaned(skills + [skill])
        }
    }

    func addOwnSkill(_ name: String) {
        let cleaned = VaultSkills.cleaned([name])
        guard let name = cleaned.first, !isChosen(name) else { return }
        skills.append(name)
    }

    // MARK: Steps

    func withoutFile() {
        go(to: .details)
    }

    func back() {
        guard canGoBack else { return }
        problem = nil
        switch page {
        case .details: go(to: .source)
        case .documents: go(to: .details)
        case .skills: go(to: .documents)
        case .source, .done: break
        }
    }

    /// Volgende: checks the page, then moves on. On the skills page it saves.
    func next() async {
        problem = nil
        switch page {
        case .source:
            go(to: .details)
        case .details:
            if let firstProblem = draft.problem {
                showsMissing = true
                problem = VaultMessages.problem(firstProblem)
                PaveHaptics.error()
            } else if !draft.missingFields.isEmpty {
                showsMissing = true
                PaveHaptics.error()
            } else {
                go(to: .documents)
            }
        case .documents:
            if wantsCover, cover == nil {
                problem = VaultMessages.coverMissing
                PaveHaptics.error()
            } else {
                go(to: .skills)
            }
        case .skills:
            await save()
        case .done:
            break
        }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let id: String
            if let savedItemID {
                id = savedItemID
            } else {
                id = try await vault.addItem(draft)
                savedItemID = id
            }
            for (index, document) in documents.enumerated() where !savedParts.contains(.document(index)) {
                try await vault.attach(document, to: id)
                savedParts.insert(.document(index))
            }
            if wantsCover, let cover, !savedParts.contains(.cover) {
                do {
                    try await vault.attach(cover, to: id)
                } catch VaultError.missingColumn {
                    coverWaits = true
                }
                savedParts.insert(.cover)
            }
            if let logo, !savedParts.contains(.logo) {
                do {
                    try await vault.attach(logo, to: id)
                } catch VaultError.missingColumn {
                    coverWaits = true
                }
                savedParts.insert(.logo)
            }
            if !skills.isEmpty, !savedParts.contains(.skills) {
                try await vault.addSkills(skills, to: id)
                savedParts.insert(.skills)
            }
            await vault.load()
            PaveHaptics.success()
            go(to: .done)
        } catch {
            problem = VaultMessages.message(for: VaultError(error))
            PaveHaptics.error()
        }
    }

    /// Afronden: only a ticked box changes anything; Ayla stays out otherwise.
    func finish() async -> Bool {
        guard let savedItemID, allowsAyla else { return true }
        isSaving = true
        defer { isSaving = false }
        do {
            try await vault.setAylaAllowed(true, itemID: savedItemID)
            await vault.load()
            return true
        } catch {
            problem = VaultMessages.message(for: VaultError(error))
            PaveHaptics.error()
            return false
        }
    }

    private func go(to page: Page) {
        movesForward = page > self.page
        self.page = page
    }
}
