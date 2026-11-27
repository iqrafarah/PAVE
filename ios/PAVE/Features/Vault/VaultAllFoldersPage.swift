import PAVECore
import SwiftUI

/// "Alle mappen": every folder in a grid, for when the row on top of the vault shows only the first few (web
/// VaultFoldersGrid). The folders keep the order of the row, pinned ones first. From this many folders on you can search
/// by name; capitals and accents do not matter.
struct VaultAllFoldersPage: View {
    @Environment(VaultModel.self) private var model
    @Environment(\.hidesScreenButtons) private var hidesScreenButtons
    @Environment(\.vaultButtonsInPage) private var buttonsInPage
    @Environment(\.menuButtonFrame) private var menuFrame
    let actions: VaultActions

    @State private var query = ""
    /// The folder held over another one while dragging, which takes its place on letting go.
    @State private var dropTarget: String?
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
        // On iPhone Duo's outer display iOS shows no toolbar buttons in the vault's sheet: the button is along the side,
        // as on the other pages of the vault.
        .overlay {
            if buttonsInPage, !hidesScreenButtons { sideButton }
        }
        .toolbar {
            if !hidesScreenButtons, !buttonsInPage {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: actions.newFolder) {
                        Image(.iconFolderPlusSolid)
                            .renderingMode(.template)
                            .foregroundStyle(Color.ink)
                            .paveToolbarHitArea()
                    }
                    .accessibilityLabel("Map aanmaken")
                }
            }
        }
    }

    private var sideButton: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            Button(action: actions.newFolder) {
                Image(.iconFolderPlusSolid)
                    .renderingMode(.template)
                    .foregroundStyle(Color.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Map aanmaken")
            .position(x: proxy.size.width + proxy.safeAreaInsets.trailing / 2, y: max(menuFrame.midY, frame.minY + 40) - frame.minY)
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
            isSelected: false,
            isDropTarget: dropTarget == folder.id
        ) {
            actions.openFolder(folder)
        }
        // The same menu as the folders on top of the vault.
        .contextMenu {
            Button {
                Task { await model.setPinned(!folder.isPinned, folder: folder) }
            } label: {
                Label { Text(folder.isPinned ? VaultMessages.unpinFolder : VaultMessages.pinFolder) } icon: { Image(folder.isPinned ? .iconBookmarkSlashSolid : .iconBookmarkSolid).renderingMode(.template) }
            }
            Button { actions.editFolder(folder) } label: {
                Label { Text("Map aanpassen") } icon: { Image(.iconPencilSolid).renderingMode(.template) }
            }
            Button(role: .destructive) { actions.deleteFolder(folder) } label: {
                Label { Text("Map verwijderen") } icon: { Image(.iconTrashSolid).renderingMode(.template) }
            }
        }
        // Drag a folder onto another one: it takes that place, as in the row on top of the vault. Not while searching,
        // when the folders in between are not on screen.
        .draggable(folder.id) {
            VaultFolderTile(title: folder.name, icon: style.icon.image, color: style.color.color, surface: style.color.surface, iconColor: style.color.foreground, isPinned: folder.isPinned, count: model.count(in: .folder(folder.id)), isSelected: false) {}
        }
        .dropDestination(for: String.self) { ids, _ in
            dropTarget = nil
            guard query.isEmpty, let id = ids.first, id != folder.id, model.folders.contains(where: { $0.id == id }) else { return false }
            PaveHaptics.selection()
            Task { await model.moveFolder(id, onto: folder.id) }
            return true
        } isTargeted: { isOver in
            if isOver { dropTarget = folder.id } else if dropTarget == folder.id { dropTarget = nil }
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
