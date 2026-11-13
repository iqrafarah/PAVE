import PAVECore
import SwiftUI

/// The vault in the panel over the chat: your items as in the list view. Tapping one opens it, with "Vraag Ayla over
/// dit bewijs"; the button at the bottom opens the whole vault.
struct AylaVaultShelf: View {
    let onAsk: (VaultItem) -> Void
    @Environment(VaultModel.self) private var vault
    @Environment(\.openFromAyla) private var openFromAyla
    @State private var openedItem: VaultItem?

    var body: some View {
        VStack(spacing: 12) {
            switch vault.state {
            case .loading:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .accessibilityLabel("Kluis laden")
            case .unavailable:
                PaveEmptyState(icon: .iconFolderSolid, title: VaultMessages.notInDemoTitle, message: VaultMessages.notInDemoMessage)
            case .failed(let error):
                PaveEmptyState(icon: .iconExclamationCircleSolid, title: VaultMessages.loadFailedTitle, message: VaultMessages.message(for: error))
            case .ready where vault.items.isEmpty:
                PaveEmptyState(icon: .iconFolderSolid, title: VaultMessages.emptyTitle, message: VaultMessages.emptyMessage)
            case .ready:
                ForEach(vault.items) { item in
                    Button { openedItem = item } label: {
                        VaultLibraryCard(item: item, isGrid: false)
                    }
                    .buttonStyle(.pave)
                }
            }

            if openFromAyla != nil {
                PaveSecondaryButton(title: AylaMessages.openVault, icon: .iconFolderSolid) {
                    openFromAyla?(AylaReply.Navigation(screen: .vault))
                }
                .frame(maxWidth: 260)
                .padding(.top, 8)
            }
        }
        .task {
            if vault.state == .loading { await vault.load() }
        }
        .sheet(item: $openedItem) { item in
            VaultItemDetailView(itemID: item.id)
                .environment(vault)
                .environment(\.askAylaAbout, onAsk)
                .paveSheet()
        }
    }
}
