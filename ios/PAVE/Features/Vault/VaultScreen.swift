import PAVECore
import SwiftUI

/// Your vault: folders on top, then everything in it as tiles or a list. It reads and writes your own Supabase rows.
struct VaultScreen: View {
    @Environment(VaultModel.self) private var model
    let onShowMenu: (() -> Void)?

    @AppStorage("vaultShowsGrid") private var isGrid = true
    @State private var filter = VaultFilter()
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool
    @State private var openedItem: VaultItem?
    @State private var editedItem: VaultItem?
    @State private var confirmedItem: VaultItem?
    @State private var addsItem = false
    @State private var deletedItem: VaultItem?
    @State private var folderSheet: FolderSheet?
    @State private var deletedFolder: VaultFolder?

    private enum FolderSheet: Identifiable {
        case new
        case edit(VaultFolder)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let folder): folder.id
            }
        }
    }

    private var visibleItems: [VaultItem] { filter.apply(to: model.items) }

    var body: some View {
        NavigationStack {
            content
                .background(Color.canvas.ignoresSafeArea())
                .mainScreenToolbar("Kluis", onShowMenu: onShowMenu)
                .toolbar {
                    if model.state == .ready {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: toggleSearch) {
                                Image(isSearching ? .iconXMark : .iconSearch)
                            }
                            .accessibilityLabel(isSearching ? "Zoeken sluiten" : "Zoeken in je kluis")
                        }
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button { addsItem = true } label: {
                                    Label { Text("Bewijs toevoegen") } icon: { Image(.iconDocumentPlusSolid) }
                                }
                                Button { folderSheet = .new } label: {
                                    Label { Text("Map aanmaken") } icon: { Image(.iconFolderPlusSolid) }
                                }
                            } label: {
                                Image(.iconPlus)
                            }
                            .accessibilityLabel("Toevoegen")
                        }
                    }
                }
                .task { await model.load() }
                .sheet(item: $openedItem) { item in
                    VaultItemDetailView(itemID: item.id)
                        .paveSheet()
                }
                .sheet(item: $editedItem) { item in
                    VaultEvidenceEditor(vault: model, item: item)
                        .paveSheet()
                }
                .sheet(item: $confirmedItem) { item in
                    VaultRequestConfirmationSheet(item: item, documentCount: model.documents(of: item).count)
                        .paveSheet()
                }
                .sheet(isPresented: $addsItem) {
                    VaultAddEvidenceSheet(vault: model, category: newItemCategory, folderID: newItemFolderID)
                        .paveSheet()
                }
                .sheet(item: $folderSheet) { sheet in
                    Group {
                        switch sheet {
                        case .new:
                            VaultFolderEditor(folder: nil, style: nil) { folder in
                                filter.shelf = .folder(folder.id)
                            }
                        case .edit(let folder):
                            VaultFolderEditor(folder: folder, style: model.style(of: folder))
                        }
                    }
                    .presentationDragIndicator(.visible)
                    .paveSheet()
                }
                .confirmationDialog("Uit je kluis verwijderen?", isPresented: isPresented($deletedItem), titleVisibility: .visible, presenting: deletedItem) { item in
                    Button("Verwijderen", role: .destructive) {
                        PaveHaptics.tap(.heavy)
                        Task { await model.delete(item) }
                    }
                } message: { _ in
                    Text(VaultMessages.deleteItemMessage)
                }
                .confirmationDialog("Map verwijderen?", isPresented: isPresented($deletedFolder), titleVisibility: .visible, presenting: deletedFolder) { folder in
                    Button("Map verwijderen", role: .destructive) {
                        if filter.shelf == .folder(folder.id) { filter.shelf = .all }
                        Task { await model.deleteFolder(folder) }
                    }
                } message: { _ in
                    Text(VaultMessages.deleteFolderMessage)
                }
                .alert("Dat lukte niet", isPresented: Binding(get: { model.problem != nil && !addsItem && editedItem == nil && openedItem == nil && folderSheet == nil }, set: { if !$0 { model.problem = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.problem ?? "")
                }
        }
        .tint(.brandGreen)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ScrollView {
                VaultLoadingView()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .frame(maxWidth: 1000)
                    .frame(maxWidth: .infinity)
            }
            .scrollDisabled(true)
        case .unavailable:
            PaveEmptyState(icon: .iconFolderSolid, title: VaultMessages.notInDemoTitle, message: VaultMessages.notInDemoMessage)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let error):
            VStack(spacing: 20) {
                PaveEmptyState(
                    icon: error == .noConnection ? .iconSignalSlash : .iconExclamationCircleSolid,
                    title: VaultMessages.loadFailedTitle,
                    message: VaultMessages.message(for: error)
                )
                PaveSecondaryButton(title: "Opnieuw proberen", icon: .iconArrowPath) {
                    Task { await model.retry() }
                }
                .frame(maxWidth: 260)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            library
        }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isSearching {
                    PaveSearchField(text: $filter.searchText, prompt: "Zoek op titel, organisatie of vaardigheid", isFocused: $isSearchFocused)
                }
                shelves
                VaultFilterBar(filter: $filter, isGrid: $isGrid)
                items
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await model.load() }
    }

    private var shelves: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(model.folders) { folder in
                    let style = model.style(of: folder)
                    VaultFolderTile(
                        title: folder.name,
                        icon: style.icon.image,
                        color: style.color.color,
                        surface: style.color.surface,
                        count: model.count(in: .folder(folder.id)),
                        isSelected: filter.shelf == .folder(folder.id)
                    ) {
                        select(.folder(folder.id))
                    }
                    .contextMenu {
                        Button { folderSheet = .edit(folder) } label: {
                            Label { Text("Map aanpassen") } icon: { Image(.iconPencil) }
                        }
                        Button(role: .destructive) { deletedFolder = folder } label: {
                            Label { Text("Map verwijderen") } icon: { Image(.iconTrash) }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var items: some View {
        let visible = visibleItems
        if visible.isEmpty {
            emptyState
                .frame(maxWidth: .infinity)
                .padding(.top, 36)
        } else if isGrid {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(visible) { card($0) }
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(visible) { card($0) }
            }
        }
    }

    private func card(_ item: VaultItem) -> some View {
        Button {
            openedItem = item
        } label: {
            VaultLibraryCard(item: item, isGrid: isGrid)
        }
        .buttonStyle(.pave)
        .accessibilityHint("Toont alles over dit item")
        .contextMenu {
            VaultItemActionButtons(item: item, onEdit: { editedItem = item }, onRequestConfirmation: { confirmedItem = item }, onDelete: { deletedItem = item })
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.items.isEmpty {
            emptyMessage(icon: .iconFolderSolid, title: VaultMessages.emptyTitle, message: VaultMessages.emptyMessage, button: "Bewijs toevoegen") {
                addsItem = true
            }
        } else if !filter.searchText.isEmpty || filter.narrowsDown {
            emptyMessage(icon: .iconSearch, title: VaultMessages.noResultsTitle, message: VaultMessages.noResultsMessage, button: "Filters wissen") {
                filter = VaultFilter()
                filter.shelf = .all
            }
        } else if case .folder(let id) = filter.shelf, let folder = model.folder(id) {
            emptyMessage(icon: .iconFolderSolid, title: "\(folder.name) is nog leeg", message: VaultMessages.emptyFolderMessage)
        } else if case .category(let category) = filter.shelf {
            emptyMessage(
                icon: category.icon,
                title: VaultMessages.emptyCategoryTitle(category),
                message: VaultMessages.emptyMessage,
                button: "\(category.singularTitle) toevoegen"
            ) {
                addsItem = true
            }
        }
    }

    private func emptyMessage(icon: ImageResource, title: String, message: String, button: String? = nil, action: @escaping () -> Void = {}) -> some View {
        VStack(spacing: 20) {
            PaveEmptyState(icon: icon, title: title, message: message)
            if let button {
                PavePrimaryButton(title: button, action: action)
                    .frame(maxWidth: 260)
            }
        }
    }

    /// Adding from an example folder starts with its kind, such as Project in Projecten.
    private var newItemCategory: VaultCategory {
        if case .category(let category) = filter.shelf { return category }
        if case .folder(let id) = filter.shelf, let folder = model.folder(id),
           let example = VaultExampleFolders.all.first(where: { $0.name.localizedCaseInsensitiveCompare(folder.name) == .orderedSame }) {
            return example.category
        }
        return .projects
    }

    private var newItemFolderID: String? {
        if case .folder(let id) = filter.shelf { return id }
        return nil
    }

    private func select(_ shelf: VaultShelf) {
        withAnimation(.snappy(duration: 0.22)) {
            filter.shelf = filter.shelf == shelf ? .all : shelf
        }
        PaveHaptics.selection()
    }

    private func toggleSearch() {
        withAnimation(.snappy(duration: 0.22)) {
            if isSearching {
                filter.searchText = ""
                isSearching = false
                isSearchFocused = false
            } else {
                isSearching = true
                isSearchFocused = true
            }
        }
    }

    private func isPresented<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}

#Preview("Kluis") {
    VaultScreen(onShowMenu: {})
        .environment(VaultModel(previewContents: .preview))
}

#Preview("Leeg") {
    VaultScreen(onShowMenu: {})
        .environment(VaultModel(previewContents: VaultContents()))
}

#Preview("Demo") {
    VaultScreen(onShowMenu: {})
        .environment(VaultModel(service: nil))
}
