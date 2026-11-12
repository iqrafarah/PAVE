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

    private enum Part { case document, cover, skills }

    private(set) var page = Page.source
    /// Which way the pages slide.
    private(set) var movesForward = true
    var draft: VaultItemDraft
    private(set) var document: VaultUpload?
    var wantsCover = false
    private(set) var cover: VaultUpload?
    private(set) var skills: [String] = []
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

    init(vault: VaultModel, category: VaultCategory, folderID: String?) {
        self.vault = vault
        initialDraft = VaultItemDraft(category: category, folderID: folderID)
        draft = initialDraft
    }

    var hasChanges: Bool {
        savedItemID == nil && (draft != initialDraft || document != nil || cover != nil || !skills.isEmpty)
    }

    /// Back is gone once the item is saved: changing the details then would not reach the vault.
    var canGoBack: Bool { page > .source && page < .done && savedItemID == nil }

    var missingFields: [VaultItemDraft.Field] { showsMissing ? draft.missingFields : [] }

    var knownSkills: [String] { VaultSkills.known(in: vault.items) }

    // MARK: Files

    func pick(_ result: Result<VaultUpload, VaultUpload.Problem>) {
        switch result {
        case .success(let upload) where upload.role == .cover:
            cover = upload
            problem = nil
        case .success(let upload):
            document = upload
            if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
                draft.title = String(upload.suggestedTitle.prefix(VaultItemDraft.maximumTitleLength))
            }
            problem = nil
        case .failure(let failure):
            problem = VaultMessages.upload(failure)
            PaveHaptics.error()
        }
    }

    func removeDocument() { document = nil }

    func removeCover() { cover = nil }

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
        document = nil
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
            if document != nil { go(to: .details) }
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
            if let document, !savedParts.contains(.document) {
                try await vault.attach(document, to: id)
                savedParts.insert(.document)
            }
            if wantsCover, let cover, !savedParts.contains(.cover) {
                do {
                    try await vault.attach(cover, to: id)
                } catch VaultError.missingColumn {
                    coverWaits = true
                }
                savedParts.insert(.cover)
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
