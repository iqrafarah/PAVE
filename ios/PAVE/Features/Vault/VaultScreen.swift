import PAVECore
import SwiftUI

/// Your vault: folders on top, then everything in it as tiles or a list. A folder opens as a page of its own, as on the
/// web; back brings you to the whole vault. The sheets and questions live here, once, for every page. It reads and
/// writes your own Supabase rows.
struct VaultScreen: View {
    @Environment(VaultModel.self) private var model
    let onShowMenu: (() -> Void)?

    @State private var path: [FolderRoute] = []
    @State private var openedItem: VaultItem?
    @State private var editedItem: VaultItem?
    @State private var confirmedItem: VaultItem?
    @State private var addFlow: VaultAddEvidenceModel?
    @State private var deletedItem: VaultItem?
    @State private var folderSheet: FolderSheet?
    @State private var deletedFolder: VaultFolder?

    private struct FolderRoute: Hashable {
        let id: String
    }

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

    private var actions: VaultActions {
        VaultActions(
            open: { openedItem = $0 },
            edit: { editedItem = $0 },
            requestConfirmation: { confirmedItem = $0 },
            delete: { deletedItem = $0 },
            add: add,
            newFolder: { folderSheet = .new },
            openFolder: { folder in
                PaveHaptics.selection()
                path.append(FolderRoute(id: folder.id))
            },
            editFolder: { folderSheet = .edit($0) },
            deleteFolder: { deletedFolder = $0 }
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Color.canvas.ignoresSafeArea())
                .navigationTitle("Kluis")
                .mainScreenToolbar("Kluis", onShowMenu: onShowMenu)
                .navigationDestination(for: FolderRoute.self) { route in
                    VaultLibraryPage(folderID: route.id, actions: actions)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                }
                .task { await model.load() }
                // Ayla pointed to one item: open it once the vault is there.
                .onChange(of: model.itemToOpen, initial: true) { openRequestedItem() }
                .onChange(of: model.state) { openRequestedItem() }
                // A folder that is gone (deleted here or on another device) closes.
                .onChange(of: model.folders.map(\.id)) { _, ids in
                    path.removeAll { !ids.contains($0.id) }
                }
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
                .sheet(item: $addFlow) { flow in
                    VaultAddEvidenceSheet(flow: flow)
                        .paveSheet()
                }
                .sheet(item: $folderSheet) { sheet in
                    Group {
                        switch sheet {
                        case .new:
                            VaultFolderEditor(folder: nil, style: nil) { folder in
                                path = [FolderRoute(id: folder.id)]
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
                        path.removeAll { $0.id == folder.id }
                        Task { await model.deleteFolder(folder) }
                    }
                } message: { _ in
                    Text(VaultMessages.deleteFolderMessage)
                }
                .alert("Dat lukte niet", isPresented: Binding(get: { model.problem != nil && addFlow == nil && editedItem == nil && openedItem == nil && folderSheet == nil }, set: { if !$0 { model.problem = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.problem ?? "")
                }
        }
        .tint(.paveAccent)
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
            VaultLibraryPage(folderID: nil, actions: actions)
        }
    }

    /// A draft closed less than half a minute ago comes back; otherwise new evidence, in the open folder and in the
    /// folder of its kind. Adding from an example folder starts with its kind, such as Project in Projecten.
    private func add(_ folder: VaultFolder?) {
        if let draft = model.takeDraft() {
            addFlow = draft
            return
        }
        let example = folder.flatMap { folder in
            VaultExampleFolders.all.first { $0.name.localizedCaseInsensitiveCompare(folder.name) == .orderedSame }
        }
        addFlow = VaultAddEvidenceModel(vault: model, category: example?.category ?? .projects, folderID: folder?.id)
    }

    private func openRequestedItem() {
        guard let id = model.itemToOpen, model.state == .ready else { return }
        model.itemToOpen = nil
        openedItem = model.items.first { $0.id == id }
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
