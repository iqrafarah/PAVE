import Foundation
import Observation
import PAVECore

/// "Voorstel van Ayla": skills that fit the form and the documents. She gets the text of PDFs and text files and small
/// photos of images, only for this proposal.
@Observable
final class VaultAylaSkills {
    enum State: Equatable {
        case idle
        case loading
        case loaded([VaultSkillSuggestion])
        case failed(String)
    }

    private(set) var state = State.idle
    /// How many files the last proposal looked at.
    private(set) var lookedAtFiles = 0
    /// The documents of the evidence as they are now, set by the flow that owns this.
    @ObservationIgnored var documents: () async -> [VaultUpload] = { [] }
    private let vault: VaultModel

    init(vault: VaultModel) {
        self.vault = vault
    }

    func ask(for draft: VaultItemDraft, existing: [String]) async {
        guard state != .loading else { return }
        state = .loading
        SupabaseVaultService.lastFailure = nil
        do {
            let material = await VaultSkillsMaterialReader.read(await documents())
            let suggestions = try await vault.suggestSkills(for: draft, material: material, existing: existing)
            lookedAtFiles = material.fileCount
            state = .loaded(suggestions)
        } catch {
            state = .failed(VaultMessages.withDetail(VaultMessages.aylaSkills(VaultError(error))))
        }
    }
}
