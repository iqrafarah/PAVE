import Foundation
import Observation
import PAVECore

/// "Voorstel van Ayla": she proposes skills only when you ask, and then only sees the fields of this form.
@Observable
final class VaultAylaSkills {
    enum State: Equatable {
        case idle
        case loading
        case loaded([VaultSkillSuggestion])
        case failed(String)
    }

    private(set) var state = State.idle
    private let vault: VaultModel

    init(vault: VaultModel) {
        self.vault = vault
    }

    func ask(for draft: VaultItemDraft, existing: [String]) async {
        guard state != .loading else { return }
        state = .loading
        SupabaseVaultService.lastFailure = nil
        do {
            state = .loaded(try await vault.suggestSkills(for: draft, existing: existing))
        } catch {
            state = .failed(VaultMessages.withDetail(VaultMessages.aylaSkills(VaultError(error))))
        }
    }
}
