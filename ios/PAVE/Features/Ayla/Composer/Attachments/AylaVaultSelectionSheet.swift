import PAVECore
import SwiftUI

/// "Item uit je kluis" from the plus button, as in Figma (FEDDIES 1348:6): your folders on top, your evidence under
/// them as in the vault, and the number chosen with "Verder" floating at the bottom. A folder chooses everything in it.
/// The sheet comes up from the bottom, can be pulled up to the full screen and swiped away. What is chosen is what the
/// conversation is about from here on; items Ayla may not use yet ask first, once for all of them.
struct AylaVaultSelectionSheet: View {
    @Environment(VaultModel.self) private var vault
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onPick: ([VaultItem]) -> Void
    @State private var selected: Set<String> = []
    @State private var asksPermission: [VaultItem]?
    @State private var detent = PresentationDetent.fraction(0.62)

    private var chosen: [VaultItem] { vault.items.filter { selected.contains($0.id) } }

    var body: some View {
        Group {
            if vault.state == .ready, vault.items.isEmpty {
                PaveEmptyState(icon: .iconFolderSolid, title: AylaMessages.vaultEmpty, message: VaultMessages.emptyMessage)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.fraction(0.62), .large], selection: $detent)
        .presentationDragIndicator(.visible)
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

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AylaMessages.pickItemTitle)
                        .textStyle(.emptyTitle)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(AylaMessages.pickItemHint)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.horizontal, 24)
                folders
                LazyVStack(spacing: 12) {
                    ForEach(vault.items) { item in
                        card(item)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        // The choice floats over the list, as in Figma, and the list scrolls on under it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VaultSelectionBar(count: selected.count, onContinue: continueWithChosen)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background {
                    LinearGradient(colors: [.white.opacity(0), .white], startPoint: .top, endPoint: .center)
                        .ignoresSafeArea()
                }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selected)
    }

    /// "Alle items" and your folders, with their colours and icons from the vault.
    private var folders: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                tile(title: AylaMessages.allItems, icon: VaultFolderIcon.folder.image, color: .paveAccent, surface: .paveSurfaceTint, items: vault.items)
                ForEach(vault.folders) { folder in
                    let style = vault.style(of: folder)
                    tile(title: folder.name, icon: style.icon.image, color: style.color.color, surface: style.color.surface, items: vault.items.filter { $0.folderIDs.contains(folder.id) })
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func tile(title: String, icon: ImageResource, color: Color, surface: Color, items: [VaultItem]) -> some View {
        let ids = Set(items.map(\.id))
        let isOn = !ids.isEmpty && ids.isSubset(of: selected)
        return VaultFolderTile(title: title, icon: icon, color: color, surface: surface, count: items.count, isSelected: isOn, checkbox: isOn) {
            guard !ids.isEmpty else { return }
            PaveHaptics.selection()
            if isOn { selected.subtract(ids) } else { selected.formUnion(ids) }
        }
        .accessibilityValue(isOn ? "Gekozen" : "Niet gekozen")
    }

    private func card(_ item: VaultItem) -> some View {
        let isOn = selected.contains(item.id)
        return Button {
            PaveHaptics.selection()
            if isOn { selected.remove(item.id) } else { selected.insert(item.id) }
        } label: {
            VaultLibraryCard(item: item, isGrid: false, isSelected: isOn)
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func continueWithChosen() {
        let items = chosen
        guard !items.isEmpty else { return }
        let notAllowed = items.filter { $0.aylaAllowedAt == nil }
        if notAllowed.isEmpty { finish(items) } else { asksPermission = notAllowed }
    }

    private func finish(_ items: [VaultItem]) {
        PaveHaptics.success()
        onPick(items)
        dismiss()
    }
}

#Preview {
    Color.canvas.sheet(isPresented: .constant(true)) {
        AylaVaultSelectionSheet { _ in }
            .environment(VaultModel(previewContents: .preview))
            .paveSheet()
    }
}
