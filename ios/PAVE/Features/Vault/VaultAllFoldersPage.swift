import PAVECore
import SwiftUI

/// "Alle mappen": every folder in a grid, for when the row on top of the vault shows only the first few (web
/// VaultFoldersGrid). The folders keep the order of the row, pinned ones first. From this many folders on you can search
/// by name; capitals and accents do not matter.
struct VaultAllFoldersPage: View {
    @Environment(VaultModel.self) private var model
    let actions: VaultActions

    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private static let searchFrom = 9

    private var shown: [VaultFolder] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return model.folders }
        return model.folders.filter { $0.name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(VaultMessages.folderCount(model.folders.count))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                if model.folders.count >= Self.searchFrom {
                    PaveSearchField(text: $query, prompt: VaultMessages.searchFolders, isFocused: $isSearchFocused)
                }
                if shown.isEmpty {
                    Text(VaultMessages.noFoldersFound(query.trimmingCharacters(in: .whitespaces)))
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: VaultFolderTile.width), spacing: 9, alignment: .top)], spacing: 12) {
                        ForEach(shown) { folder in
                            tile(folder)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle(VaultMessages.allFoldersTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: actions.newFolder) {
                    Image(.iconFolderPlusSolid)
                        .paveToolbarHitArea()
                }
                .accessibilityLabel("Map aanmaken")
            }
        }
    }

    private func tile(_ folder: VaultFolder) -> some View {
        let style = model.style(of: folder)
        return VaultFolderTile(
            title: folder.name,
            icon: style.icon.image,
            color: style.color.color,
            surface: style.color.surface,
            iconColor: style.color.foreground,
            isPinned: folder.isPinned,
            count: model.count(in: .folder(folder.id)),
            isSelected: false
        ) {
            actions.openFolder(folder)
        }
        .contextMenu {
            Button(folder.isPinned ? VaultMessages.unpinFolder : VaultMessages.pinFolder, systemImage: folder.isPinned ? "pin.slash" : "pin") {
                Task { await model.setPinned(!folder.isPinned, folder: folder) }
            }
            if query.isEmpty {
                Button("Naar voren", systemImage: "arrow.backward") { move(folder, by: -1) }
                    .disabled(model.folders.first == folder)
                Button("Naar achteren", systemImage: "arrow.forward") { move(folder, by: 1) }
                    .disabled(model.folders.last == folder)
            }
            Button { actions.editFolder(folder) } label: {
                Label { Text("Map aanpassen") } icon: { Image(.iconPencil) }
            }
            Button(role: .destructive) { actions.deleteFolder(folder) } label: {
                Label { Text("Map verwijderen") } icon: { Image(.iconTrash) }
            }
        }
        .accessibilityAction(named: "Naar voren") { move(folder, by: -1) }
        .accessibilityAction(named: "Naar achteren") { move(folder, by: 1) }
    }

    private func move(_ folder: VaultFolder, by step: Int) {
        let folders = model.folders
        guard let index = folders.firstIndex(of: folder), folders.indices.contains(index + step) else { return }
        PaveHaptics.selection()
        Task { await model.moveFolder(folder.id, onto: folders[index + step].id) }
    }
}
