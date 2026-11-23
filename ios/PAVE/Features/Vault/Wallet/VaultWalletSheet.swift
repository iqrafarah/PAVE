import PAVECore
import SwiftUI

/// "Je wallet" (demo for Npuls): the credentials in a made-up wallet, of which you pick what goes into the vault. They
/// come in confirmed, the way evidence a school signed would. Opened from the first step of "Bewijs toevoegen".
struct VaultWalletSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var wallet: VaultWalletModel
    /// Called with how many came in, so "Bewijs toevoegen" can close as well.
    let onImported: (Int) -> Void

    init(vault: VaultModel, folderID: String?, onImported: @escaping (Int) -> Void) {
        _wallet = State(initialValue: VaultWalletModel(vault: vault, folderID: folderID))
        self.onImported = onImported
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            if wallet.state == .ready, !wallet.available.isEmpty {
                footer
            }
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.panel.ignoresSafeArea())
        .tint(.paveAccent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(wallet.isImporting)
        .task { await wallet.load() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(VaultMessages.walletTitle)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(VaultMessages.walletIntro)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(18)
                    .foregroundStyle(Color.ink)
                    .frame(width: 44, height: 44)
            }
            .padding(.top, -10)
            .padding(.trailing, -12)
            .buttonStyle(.pave)
            .disabled(wallet.isImporting)
            .accessibilityLabel("Sluiten")
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch wallet.state {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text(VaultMessages.walletLoading)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 16) {
                PaveNotice(message: message, tone: .critical)
                PaveSoftButton(title: VaultMessages.walletRetry) {
                    Task { await wallet.load() }
                }
            }
            .padding(24)
        case .ready:
            ScrollView {
                VStack(spacing: 12) {
                    PaveNotice(title: VaultMessages.walletDemoTitle, message: VaultMessages.walletDemoMessage)
                        .padding(.bottom, 4)
                    if wallet.available.isEmpty {
                        PaveIconLabel(icon: .iconInformationCircle, text: VaultMessages.walletAllInVault)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(wallet.credentials) { credential in
                        VaultWalletCard(
                            credential: credential,
                            isSelected: wallet.isSelected(credential),
                            checksDone: wallet.checked[credential.id] ?? (wallet.isImporting && wallet.isSelected(credential) ? 0 : nil)
                        ) {
                            PaveHaptics.selection()
                            wallet.toggle(credential)
                        }
                    }
                    if let problem = wallet.problem {
                        PaveNotice(message: problem, tone: .critical)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var footer: some View {
        PavePrimaryButton(
            title: wallet.selected.isEmpty ? VaultMessages.walletChooseFirst : VaultMessages.walletAdd(wallet.selected.count),
            loadingTitle: VaultMessages.walletChecking,
            isLoading: wallet.isImporting
        ) {
            Task {
                guard let count = await wallet.importSelected() else { return }
                let added = VaultMessages.walletAdded(count)
                AccessibilityNotification.Announcement(added).post()
                onImported(count)
                dismiss()
            }
        }
        .disabled(wallet.selected.isEmpty)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}
