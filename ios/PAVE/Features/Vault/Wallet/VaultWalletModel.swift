import Foundation
import Observation
import PAVECore

/// "Haal bewijs uit je wallet" (demo for Npuls), inside "Bewijs toevoegen": choose credentials from the made-up wallet,
/// watch them being checked one by one, then decide whether Ayla may use them. The check is played, not real; the
/// screens say so.
@Observable
final class VaultWalletModel {
    enum State: Equatable {
        case loading
        case ready
        case failed(String)
    }

    enum Phase: Int {
        case choose
        case checking
        case done
    }

    /// The three things a real verifier checks, in the order they run on a card.
    enum Check: Int, CaseIterable {
        case signature
        case issuer
        case notRevoked

        /// What the card says while this check runs.
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
    private(set) var phase = Phase.choose
    /// The way the pages last moved, for the push of the next one.
    private(set) var movesForward = true
    private(set) var credentials: [VaultWalletCredential] = []
    private(set) var selected: [String] = []
    /// Per credential being checked, how many checks are done.
    private(set) var checked: [String: Int] = [:]
    /// The items the chosen credentials became in the vault.
    private(set) var itemIDs: [String] = []
    var allowsAyla = false
    var problem: String?
    private(set) var isFinishing = false
    /// How long one check takes on screen; zero in tests.
    var checkDuration: Duration = .milliseconds(420)

    init(vault: VaultModel, folderID: String?) {
        self.vault = vault
        self.folderID = folderID
    }

    var available: [VaultWalletCredential] { credentials.filter { !$0.imported } }
    /// The chosen credentials, in the order of the wallet.
    var chosen: [VaultWalletCredential] { credentials.filter { selected.contains($0.id) } }
    var isChecking: Bool { phase == .checking }

    func load() async {
        do {
            credentials = try await vault.walletCredentials()
            state = .ready
        } catch {
            state = .failed(VaultError(error) == .notSetUp ? VaultMessages.walletNotSetUp : VaultMessages.walletFailed)
        }
    }

    func toggle(_ credential: VaultWalletCredential) {
        guard !credential.imported, phase == .choose else { return }
        if let index = selected.firstIndex(of: credential.id) { selected.remove(at: index) } else { selected.append(credential.id) }
    }

    func isSelected(_ credential: VaultWalletCredential) -> Bool { selected.contains(credential.id) }

    func checksDone(_ credential: VaultWalletCredential) -> Int { checked[credential.id] ?? 0 }

    func isVerified(_ credential: VaultWalletCredential) -> Bool { checksDone(credential) >= Check.allCases.count }

    /// Goes to the check: each chosen card is checked in turn while the server puts them in the vault, and when both
    /// are done the last step opens. When it does not work, you are back at choosing, with your choice.
    func start() async {
        let chosen = chosen
        guard !chosen.isEmpty, phase == .choose else { return }
        problem = nil
        checked = [:]
        movesForward = true
        phase = .checking
        let folderID = folderID
        let saving = Task { try await vault.importFromWallet(chosen, folderID: folderID) }
        for credential in chosen {
            for check in Check.allCases {
                try? await Task.sleep(for: checkDuration)
                checked[credential.id] = check.rawValue + 1
            }
            PaveHaptics.selection()
        }
        do {
            itemIDs = try await saving.value
            PaveHaptics.success()
            phase = .done
        } catch {
            problem = VaultMessages.walletImportFailed
            checked = [:]
            movesForward = false
            phase = .choose
        }
    }

    /// The last step: Ayla gets the use of the new items only when you switched it on.
    func finish() async -> Bool {
        guard phase == .done, !isFinishing else { return false }
        isFinishing = true
        defer { isFinishing = false }
        guard allowsAyla else { return true }
        for itemID in itemIDs {
            try? await vault.setAylaAllowed(true, itemID: itemID)
        }
        await vault.load()
        return true
    }
}
