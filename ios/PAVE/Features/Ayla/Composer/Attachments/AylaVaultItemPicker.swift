import PAVECore
import SwiftUI

/// "Item uit je kluis" from the plus button: pick the evidence the conversation is about. An item Ayla may not use yet
/// asks first, as "Vraag Ayla over dit bewijs" does.
struct AylaVaultItemPicker: View {
    @Environment(VaultModel.self) private var vault
    @Environment(\.dismiss) private var dismiss
    let onPick: (VaultItem) -> Void
    @State private var search = ""
    @State private var asksPermission: VaultItem?

    private var items: [VaultItem] {
        var filter = VaultFilter()
        filter.searchText = search
        return filter.apply(to: vault.items)
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    PaveEmptyState(icon: search.isEmpty ? .iconFolderSolid : .iconSearch, title: search.isEmpty ? AylaMessages.vaultEmpty : VaultMessages.noResultsTitle, message: search.isEmpty ? VaultMessages.emptyMessage : VaultMessages.noResultsMessage)
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(items) { item in
                        Button { choose(item) } label: {
                            HStack(spacing: 12) {
                                Image(item.category.icon)
                                    .renderingMode(.template)
                                    .foregroundStyle(Color.paveAccent)
                                    .paveIconFrame(22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .textStyle(.label)
                                        .foregroundStyle(Color.ink)
                                    Text([item.category.singularTitle, item.organisationName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                        .textStyle(.caption)
                                        .foregroundStyle(Color.inkMuted)
                                }
                                Spacer(minLength: 0)
                                if item.aylaAllowedAt == nil {
                                    Text("Nog niet voor Ayla")
                                        .textStyle(.meta)
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.pave)
                        .listRowBackground(Color.white)
                    }
                    .listStyle(.plain)
                    .searchable(text: $search, prompt: "Zoek in je kluis")
                }
            }
            .background(Color.canvas)
            .navigationTitle(AylaMessages.pickItemTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
            }
            .task { if vault.state != .ready { await vault.load() } }
            .confirmationDialog(AylaMessages.askNotAllowedTitle, isPresented: Binding(get: { asksPermission != nil }, set: { if !$0 { asksPermission = nil } }), titleVisibility: .visible, presenting: asksPermission) { item in
                Button(AylaMessages.askAllow) {
                    Task {
                        try? await vault.setAylaAllowed(true, itemID: item.id)
                        await vault.load()
                        finish(item)
                    }
                }
                Button(AylaMessages.askWithout) { finish(item) }
                Button("Annuleren", role: .cancel) {}
            } message: { _ in
                Text(AylaMessages.askNotAllowedMessage)
            }
        }
        .tint(.paveAccent)
    }

    private func choose(_ item: VaultItem) {
        if item.aylaAllowedAt == nil { asksPermission = item } else { finish(item) }
    }

    private func finish(_ item: VaultItem) {
        PaveHaptics.selection()
        onPick(item)
        dismiss()
    }
}
