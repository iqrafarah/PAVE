import Foundation
import Observation
import PAVECore

/// "Haal bewijs uit je wallet" (demo for Npuls): the credentials of the made-up wallet, which ones you chose, and the
/// check that is played while they go into the vault. The check is not real; the screen says so.
@Observable
final class VaultWalletModel {
    enum State: Equatable {
        case loading
        case ready
        case failed(String)
    }

    /// The three things a real verifier would check, in the order they tick off.
    enum Check: Int, CaseIterable {
        case signature
        case issuer
        case notRevoked

        /// What shows on the card while this check runs.
        var progress: String {
            switch self {
            case .signature: VaultMessages.walletCheckSignature
            case .issuer: VaultMessages.walletCheckIssuer
            case .notRevoked: VaultMessages.walletCheckRevoked
            }
        }
    }

    let vault: VaultModel
    /// The folder "Bewijs toevoegen" was opened from; what comes in goes there too.
    let folderID: String?
    private(set) var state = State.loading
    private(set) var credentials: [VaultWalletCredential] = []
    private(set) var selected: Set<String> = []
    /// Per credential being checked, how many checks are done.
    private(set) var checked: [String: Int] = [:]
    private(set) var isImporting = false
    var problem: String?
    /// How long one check takes on screen; zero in tests.
    var checkDuration: Duration = .milliseconds(380)

    init(vault: VaultModel, folderID: String?) {
        self.vault = vault
        self.folderID = folderID
    }

    var available: [VaultWalletCredential] { credentials.filter { !$0.imported } }
    var chosen: [VaultWalletCredential] { credentials.filter { selected.contains($0.id) } }

    func load() async {
        do {
            credentials = try await vault.walletCredentials()
            state = .ready
        } catch {
            state = .failed(VaultError(error) == .notSetUp ? VaultMessages.walletNotSetUp : VaultMessages.walletFailed)
        }
    }

    func toggle(_ credential: VaultWalletCredential) {
        guard !credential.imported, !isImporting else { return }
        if selected.contains(credential.id) { selected.remove(credential.id) } else { selected.insert(credential.id) }
    }

    func isSelected(_ credential: VaultWalletCredential) -> Bool { selected.contains(credential.id) }

    /// Plays the check for each chosen credential while the server puts them in the vault. Returns how many came in,
    /// or nil when it did not work.
    func importSelected() async -> Int? {
        let chosen = chosen
        guard !chosen.isEmpty, !isImporting else { return nil }
        isImporting = true
        problem = nil
        defer { isImporting = false }
        let folderID = folderID
        let saving = Task { try await vault.importFromWallet(chosen, folderID: folderID) }
        for credential in chosen {
            for check in Check.allCases {
                try? await Task.sleep(for: checkDuration)
                checked[credential.id] = check.rawValue + 1
            }
        }
        do {
            let count = try await saving.value
            PaveHaptics.success()
            return count
        } catch {
            checked = [:]
            problem = VaultMessages.walletImportFailed
            return nil
        }
    }
}
