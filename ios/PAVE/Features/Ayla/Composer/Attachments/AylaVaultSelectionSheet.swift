import PAVECore
import SwiftUI

/// "Item uit je kluis" from the plus button: the vault as the picker designed for Ayla (Figma "Ayla · toestemming
/// kluis"), with kinds to tick on and the items under them, several at once. What is chosen is what the conversation is
/// about from here on. Items Ayla may not use yet ask first, as "Vraag Ayla over dit bewijs" does.
struct AylaVaultSelectionSheet: View {
    @Environment(VaultModel.self) private var vault
    @Environment(\.dismiss) private var dismiss
    let onPick: ([VaultItem]) -> Void
    @State private var selectedCategories: Set<String> = []
    @State private var selectedItems: Set<String> = []
    @State private var asksPermission: [VaultItem]?

    /// The ticked items, and every item of a ticked kind ("Alle items" is all of them).
    private var chosen: [VaultItem] {
        vault.items.filter { item in
            selectedItems.contains(item.id) || selectedCategories.contains("all") || selectedCategories.contains(item.category.id)
        }
    }

    var body: some View {
        Group {
            if vault.items.isEmpty {
                PaveEmptyState(icon: .iconFolderSolid, title: AylaMessages.vaultEmpty, message: VaultMessages.emptyMessage)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
            } else {
                VaultAccessSelectionPanel(items: vault.items, selectedCategories: $selectedCategories, selectedItems: $selectedItems) {
                    continueWithChosen()
                }
            }
        }
        .task { if vault.state != .ready { await vault.load() } }
        .confirmationDialog(
            AylaMessages.askNotAllowedTitle(asksPermission?.count ?? 1),
            isPresented: Binding(get: { asksPermission != nil }, set: { if !$0 { asksPermission = nil } }),
            titleVisibility: .visible,
            presenting: asksPermission
        ) { notAllowed in
            Button(AylaMessages.askAllowAll) {
                let items = chosen
                Task {
                    for item in notAllowed { try? await vault.setAylaAllowed(true, itemID: item.id) }
                    await vault.load()
                    finish(items)
                }
            }
            Button(AylaMessages.askWithoutThem) { finish(chosen) }
            Button("Annuleren", role: .cancel) {}
        } message: { _ in
            Text(AylaMessages.askNotAllowedMessage)
        }
        .tint(.paveAccent)
    }

    private func continueWithChosen() {
        let items = chosen
        guard !items.isEmpty else { return }
        let notAllowed = items.filter { $0.aylaAllowedAt == nil }
        if notAllowed.isEmpty { finish(items) } else { asksPermission = notAllowed }
    }

    private func finish(_ items: [VaultItem]) {
        PaveHaptics.selection()
        onPick(items)
        dismiss()
    }
}

#Preview {
    Color.canvas.sheet(isPresented: .constant(true)) {
        AylaVaultSelectionSheet { _ in }
            .environment(VaultModel(previewContents: .preview))
    }
}
