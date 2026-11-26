import PAVECore
import SwiftUI

/// One page of the vault: the whole vault with the folder row on top, or a folder you opened from it, as on the web.
/// The search field, the folders (or the folder's name) and the filter bar stay in place; only the evidence scrolls. On a
/// screen without the height for that (a phone on its side) everything scrolls together.
///
/// Press and hold a card or a folder to drag it. Both move along live to where you hold them, as apps do on the Home
/// Screen; a card then puts the vault in "Eigen volgorde". A card let go on a folder goes into it; in an open folder the
/// other folders appear while you drag a card. Without dragging, a card has "Verplaatsen naar" in the menu of the long
/// press, and VoiceOver can move a folder forward or back.
struct VaultLibraryPage: View {
    @Environment(VaultModel.self) private var model
    /// The open folder; nil is the whole vault.
    let folderID: String?
    let actions: VaultActions

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// The open menu on the outer display of iPhone Duo puts its own buttons where search and add are.
    @Environment(\.hidesScreenButtons) private var hidesScreenButtons
    @Environment(\.vaultButtonsInPage) private var buttonsInPage
    @Environment(PaveCameraControl.self) private var cameraControl: PaveCameraControl?
    @Environment(\.menuButtonFrame) private var menuFrame
    @Environment(\.paveReduceMotion) private var reduceMotion
    /// How the vault opens, from Instellingen; switching here lasts until the vault is opened again.
    @State private var isGrid = PaveAppearance.vaultLayout == .grid
    /// The evidence moved under the folders and the filter bar: a thin line then separates them.
    @State private var itemsScrolled = false
    @State private var filter = VaultFilter()
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool
    /// What is being dragged, the folder it hovers over, and the order of the folders and cards while dragging.
    @State private var drag: VaultDrag?
    @State private var dropTarget: String?
    @State private var liveOrder: [String]?
    @State private var liveItems: [String]?
    /// The drag really moves; a long press that only opens the menu never gets here.
    @State private var isDragging = false
    /// The vault opens in "Eigen volgorde" once you made one.
    @State private var choseOrder = false
    /// The swap that just happened, so the layout can settle before the next one.
    @State private var lastSwap: VaultSwap?
    /// The folder row while a folder is dragged: where the finger is, how far the row is scrolled, how wide it shows,
    /// and where each tile is, so the row places the folder and scrolls itself near its edges.
    @State private var fingerX: CGFloat?
    /// Where the finger is on screen, which stays put while the row scrolls under it.
    @State private var fingerVisibleX: CGFloat?
    @State private var rowOffset: CGFloat = 0
    @State private var rowWidth: CGFloat = 0
    @State private var rowPosition = ScrollPosition()
    @State private var rowScroller: Task<Void, Never>?
    private static let tileSpacing: CGFloat = 9
    /// The row shows this many folders; with more, it ends with "Alle mappen" (as on the web).
    private static let rowLimit = 5
    private static let scrollEdge: CGFloat = 56
    @Namespace private var dragSpace

    private var folder: VaultFolder? { model.folder(folderID) }

    private var visibleItems: [VaultItem] {
        let items = folderID.map { id in model.items.filter { $0.folderIDs.contains(id) } } ?? model.items
        let sorted = filter.apply(to: items)
        guard let liveItems else { return sorted }
        return sorted.sorted { (liveItems.firstIndex(of: $0.id) ?? .max) < (liveItems.firstIndex(of: $1.id) ?? .max) }
    }

    /// The folder or evidence chosen with the Camera Control button, lit up and scrolled into view.
    private var chosenFolderID: String? {
        cameraControl?.highlight.flatMap { $0.menu == "folders" ? $0.key : nil }
    }

    private var chosenItemID: String? {
        cameraControl?.highlight.flatMap { $0.menu == "items" ? $0.key : nil }
    }

    var body: some View {
        ScrollViewReader { proxy in
            library
                .onChange(of: chosenItemID) { _, id in
                    guard let id else { return }
                    withAnimation(.snappy(duration: 0.3)) { proxy.scrollTo(id, anchor: .center) }
                }
        }
            .onChange(of: chosenFolderID) { _, id in
                guard let id, let index = shownFolders.firstIndex(where: { $0.id == id }), rowWidth > 0 else { return }
                let slot = VaultFolderTile.width + Self.tileSpacing
                let contentWidth = CGFloat(shownFolders.count) * slot - Self.tileSpacing
                let x = min(max(CGFloat(index) * slot - (rowWidth - VaultFolderTile.width) / 2, 0), max(contentWidth - rowWidth, 0))
                withAnimation(.snappy(duration: 0.3)) { rowPosition.scrollTo(x: x) }
            }
            .overlay {
                if buttonsInPage, !hidesScreenButtons { sideButtons }
            }
            .cameraControlMenus("vault-\(folderID ?? "root")", menus: cameraMenus, press: { actions.scan(folder) })
            .background(Color.canvas.ignoresSafeArea())
            .onAppear {
                guard !choseOrder else { return }
                choseOrder = true
                if model.items.contains(where: { $0.position != nil }) { filter.order = .custom }
            }
            .toolbar {
                if !hidesScreenButtons, !buttonsInPage {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: toggleSearch) {
                            Image(isSearching ? .iconXMark : .iconSearch)
                                .renderingMode(.template)
                                .foregroundStyle(Color.ink)
                                .paveToolbarHitArea()
                        }
                        .accessibilityLabel(isSearching ? "Zoeken sluiten" : folder.map { "Zoeken in \($0.name)" } ?? "Zoeken in je kluis")
                    }
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    ToolbarItem(placement: .topBarTrailing) {
                        addButton
                    }
                }
            }
    }

    /// Search and add in the status column along the side, under each other like the buttons of the bar: for the vault in
    /// a sheet on iPhone Duo's outer display, where iOS shows no toolbar buttons. The first one is level with the menu
    /// button, or just under the top of the sheet when that is lower.
    private var sideButtons: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let x = proxy.size.width + proxy.safeAreaInsets.trailing / 2
            let y = max(menuFrame.midY, frame.minY + 40) - frame.minY
            ZStack(alignment: .topLeading) {
                Button(action: toggleSearch) {
                    Image(isSearching ? .iconXMark : .iconSearch)
                        .renderingMode(.template)
                        .foregroundStyle(Color.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.pave)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(isSearching ? "Zoeken sluiten" : folder.map { "Zoeken in \($0.name)" } ?? "Zoeken in je kluis")
                .position(x: x, y: y)

                addButton
                    .buttonStyle(.pave)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .position(x: x, y: y + 60)
            }
        }
    }

    /// Knopmodus in the vault: the folders (in the whole vault) and the evidence on this page; a full press on an item
    /// opens it, without one it scans a document.
    private var cameraMenus: [CameraMenu] {
        var menus: [CameraMenu] = []
        let folders = shownFolders
        if folder == nil, !folders.isEmpty {
            menus.append(CameraMenu(id: "folders", title: "Map", symbol: "folder", items: folders.map(\.name), keys: folders.map(\.id), onPress: { index in
                if folders.indices.contains(index) { actions.openFolder(folders[index]) }
            }))
        }
        let items = Array(visibleItems.prefix(20))
        if !items.isEmpty {
            menus.append(CameraMenu(id: "items", title: "Bewijs", symbol: "doc.text", items: items.map(\.title), keys: items.map(\.id), onPress: { index in
                if items.indices.contains(index) { actions.open(items[index]) }
            }))
        }
        return menus
    }

    @ViewBuilder
    private var plusIcon: some View {
        if buttonsInPage {
            Image(.iconPlus)
                .renderingMode(.template)
                .foregroundStyle(Color.ink)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        } else {
            Image(.iconPlus)
                .paveToolbarHitArea()
        }
    }

    @ViewBuilder
    private var addButton: some View {
        if let folder {
            Button { actions.add(folder) } label: {
                plusIcon
            }
            .accessibilityLabel("Bewijs toevoegen aan \(folder.name)")
        } else {
            Menu {
                Button { actions.add(nil) } label: {
                    Label { Text("Bewijs toevoegen") } icon: { Image(.iconDocumentPlusSolid) }
                }
                Button(action: actions.newFolder) {
                    Label { Text("Map aanmaken") } icon: { Image(.iconFolderPlusSolid) }
                }
            } label: {
                plusIcon
            }
            .accessibilityLabel("Toevoegen")
        }
    }

    @ViewBuilder
    private var library: some View {
        if verticalSizeClass == .compact {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    controls
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
        } else {
            VStack(spacing: 0) {
                controls
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .frame(maxWidth: 1000)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.cardBorder)
                            .frame(height: 1)
                            .opacity(itemsScrolled ? 1 : 0)
                            .animation(.easeOut(duration: 0.15), value: itemsScrolled)
                    }
                    .zIndex(1)
                ScrollView {
                    items
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 28)
                        .frame(maxWidth: 1000)
                        .frame(maxWidth: .infinity)
                }
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 1 } action: { _, scrolled in
                    itemsScrolled = scrolled
                }
                .scrollDismissesKeyboard(.immediately)
                .refreshable { await model.load() }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            if isSearching {
                PaveSearchField(text: $filter.searchText, prompt: "Zoek op titel, organisatie of vaardigheid", isFocused: $isSearchFocused)
            }
            if let folder {
                VaultFolderHeader(folder: folder, count: model.count(in: .folder(folder.id)), onEdit: { actions.editFolder(folder) }, onDelete: { actions.deleteFolder(folder) })
                if case .item = drag, isDragging {
                    dropRow(excluding: folder)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                shelves
            }
            VaultFilterBar(filter: $filter, isGrid: $isGrid)
        }
        .animation(.snappy(duration: 0.25), value: drag)
    }

    // MARK: Folders

    private var shownFolders: [VaultFolder] {
        guard let liveOrder else { return model.folders }
        return liveOrder.compactMap { model.folder($0) }
    }

    private var shelves: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Self.tileSpacing) {
                ForEach(shownFolders.prefix(Self.rowLimit)) { folder in
                    shelf(folder)
                }
                if model.folders.count > Self.rowLimit {
                    VaultAllFoldersTile(count: model.folders.count, action: actions.openAllFolders)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 2)
            .vaultDragContainer(in: dragSpace, onStart: startDrag, onActive: { isDragging = true }, onEnd: endDrag)
            // While a folder is dragged, a still layer over the row measures where the finger is.
            .overlay {
                if case .folder = drag {
                    Color.clear
                        .contentShape(.rect)
                        .onDrop(of: [.text], delegate: VaultFolderRowDropDelegate(fingerX: $fingerX, onDrop: endDrag))
                        // Only in the way while the drag really moves; if its end was never heard, a tap clears it.
                        .allowsHitTesting(isDragging)
                        .onTapGesture { endDrag() }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .mask {
            // Next to the status column the tiles fade out instead of being cut off, and the buttons there stay clear.
            HStack(spacing: 0) {
                Rectangle()
                if buttonsInPage {
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 36)
                }
            }
            .padding(.vertical, -40)
        }
        .scrollPosition($rowPosition)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x + $0.contentInsets.leading } action: { _, x in rowOffset = x }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .onChange(of: fingerX) { newValue in
            if let newValue { fingerVisibleX = newValue - rowOffset }
            placeDraggedFolder()
        }
    }

    /// The dragged folder takes the slot under the finger, once the finger is past the middle of it. The finger's place
    /// is in the row's content, so the tiles sliding under it and the row scrolling change nothing.
    private func placeDraggedFolder() {
        guard case .folder(let id) = drag, let fingerX, var order = liveOrder, let from = order.firstIndex(of: id) else { return }
        let slotWidth = VaultFolderTile.width + Self.tileSpacing
        let x = fingerX
        let slot = min(max(Int(x / slotWidth), 0), min(order.count, Self.rowLimit) - 1)
        let inSlot = x - CGFloat(slot) * slotWidth
        let pastMiddle = slot > from ? inSlot > VaultFolderTile.width / 2 : inSlot < VaultFolderTile.width / 2
        guard slot != from, pastMiddle else { return }
        order.move(fromOffsets: IndexSet(integer: from), toOffset: slot > from ? slot + 1 : slot)
        withAnimation(.snappy(duration: 0.28)) { liveOrder = order }
        PaveHaptics.selection()
    }

    /// Holding a folder near the left or right edge scrolls the row further, as long as there is more.
    private func startRowScrolling() {
        rowScroller?.cancel()
        rowScroller = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard case .folder = drag, let visibleX = fingerVisibleX, rowWidth > 0 else { continue }
                let contentWidth = CGFloat(min(shownFolders.count, Self.rowLimit)) * (VaultFolderTile.width + Self.tileSpacing) - Self.tileSpacing
                let step: CGFloat = visibleX < Self.scrollEdge ? -6 : visibleX > rowWidth - Self.scrollEdge ? 6 : 0
                guard step != 0 else { continue }
                let next = min(max(rowOffset + step, 0), max(contentWidth - rowWidth, 0))
                guard next != rowOffset else { continue }
                withAnimation(nil) { rowPosition.scrollTo(x: next) }
                rowOffset = next
                // The finger did not move, so the system says nothing; the row did, so the finger is over another place.
                fingerX = visibleX + next
            }
        }
    }

    /// In an open folder, while a card is dragged: the other folders to drop it on.
    private func dropRow(excluding current: VaultFolder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(VaultMessages.dragToFolder)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    ForEach(model.folders.filter { $0.id != current.id }) { folder in
                        tile(folder) {}
                            .onDrop(of: [.text], delegate: delegate(for: folder))
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private func tile(_ folder: VaultFolder, action: @escaping () -> Void) -> VaultFolderTile {
        let style = model.style(of: folder)
        return VaultFolderTile(
            title: folder.name,
            icon: style.icon.image,
            color: style.color.color,
            surface: style.color.surface,
            iconColor: style.color.foreground,
            isPinned: folder.isPinned,
            count: model.count(in: .folder(folder.id)),
            isSelected: chosenFolderID == folder.id,
            isDropTarget: dropTarget == folder.id,
            action: action
        )
    }

    private func shelf(_ folder: VaultFolder) -> some View {
        tile(folder) { actions.openFolder(folder) }
            // The spot the dragged folder will take stays visible but faint, as on the Home Screen.
            .opacity(isDragging && drag == .folder(folder.id) ? 0.35 : 1)
            .contextMenu {
                Button {
                    Task { await model.setPinned(!folder.isPinned, folder: folder) }
                } label: {
                    Label { Text(folder.isPinned ? VaultMessages.unpinFolder : VaultMessages.pinFolder) } icon: { Image(folder.isPinned ? .iconBookmarkSlashSolid : .iconBookmarkSolid).renderingMode(.template) }
                }
                Button { actions.editFolder(folder) } label: {
                    Label { Text("Map aanpassen") } icon: { Image(.iconPencil) }
                }
                Button(role: .destructive) { actions.deleteFolder(folder) } label: {
                    Label { Text("Map verwijderen") } icon: { Image(.iconTrash) }
                }
            }
            .vaultDraggable(.folder(folder.id), in: dragSpace)
            .onDrop(of: [.text], delegate: delegate(for: folder))
            .accessibilityAction(named: "Naar voren") { moveFolder(folder, by: -1) }
            .accessibilityAction(named: "Naar achteren") { moveFolder(folder, by: 1) }
    }

    private func delegate(for folder: VaultFolder) -> VaultFolderDropDelegate {
        VaultFolderDropDelegate(folderID: folder.id, drag: drag, target: $dropTarget, onDropItem: { drop($0, on: folder) }, onDropFolder: endDrag)
    }

    /// The system may ask for the dragged item more than once during one drag; only the first time starts it.
    private func startDrag(_ dragged: VaultDrag) {
        guard drag != dragged else { return }
        drag = dragged
        dropTarget = nil
        lastSwap = nil
        fingerX = nil
        liveOrder = model.folders.map(\.id)
        liveItems = visibleItems.map(\.id)
        if case .folder = dragged { startRowScrolling() }
        // A long press that only opens the menu starts a drag that never moves, and may never report its end.
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if drag == dragged, !isDragging { endDrag() }
        }
    }

    /// The finger is lifted: what was dragged stays where it was moved to, wherever it was let go. Cards that changed
    /// places put the vault in "Eigen volgorde".
    private func endDrag() {
        guard let ended = drag else { return }
        let folders = liveOrder
        let cards = liveItems
        let cardsMoved = cards != nil && cards != filter.apply(to: visibleItemsBeforeDrag).map(\.id)
        drag = nil
        dropTarget = nil
        isDragging = false
        fingerX = nil
        fingerVisibleX = nil
        rowScroller?.cancel()
        rowScroller = nil
        Task {
            switch ended {
            case .folder:
                if let folders, folders != model.folders.map(\.id) { await model.setFolderOrder(folders) }
            case .item:
                if cardsMoved, let cards {
                    await model.setItemOrder(cards)
                    filter.order = .custom
                    choseOrder = true
                }
            }
            liveOrder = nil
            liveItems = nil
        }
    }

    /// The cards on screen as the filter shows them, without the order being dragged.
    private var visibleItemsBeforeDrag: [VaultItem] {
        folderID.map { id in model.items.filter { $0.folderIDs.contains(id) } } ?? model.items
    }

    /// A card goes into the folder; from an open folder it moves out of that one.
    private func drop(_ itemID: String, on folder: VaultFolder) {
        guard let item = model.items.first(where: { $0.id == itemID }) else { return }
        if item.folderIDs.contains(folder.id) {
            PaveHaptics.selection()
            return
        }
        Task { await model.move(item, to: folder, from: folderID) }
        AccessibilityNotification.Announcement(VaultMessages.movedInto(item.title, folder: folder.name)).post()
    }

    private func moveFolder(_ folder: VaultFolder, by step: Int) {
        let folders = model.folders
        guard let index = folders.firstIndex(of: folder), folders.indices.contains(index + step) else { return }
        Task { await model.moveFolder(folder.id, onto: folders[index + step].id) }
    }

    // MARK: Evidence

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
            .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: visible.map(\.id))
            .vaultDragContainer(in: dragSpace, onStart: startDrag, onActive: { isDragging = true }, onEnd: endDrag)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(visible) { card($0) }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: visible.map(\.id))
            .vaultDragContainer(in: dragSpace, onStart: startDrag, onActive: { isDragging = true }, onEnd: endDrag)
        }
    }

    private func card(_ item: VaultItem) -> some View {
        Button {
            actions.open(item)
        } label: {
            VaultLibraryCard(item: item, isGrid: isGrid)
                .overlay {
                    if chosenItemID == item.id {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.paveAccent, lineWidth: 3)
                    }
                }
                .scaleEffect(chosenItemID == item.id ? 1.02 : 1)
                .animation(.spring(duration: 0.3, bounce: 0.25), value: chosenItemID == item.id)
        }
        .buttonStyle(.pave)
        .id(item.id)
        .accessibilityHint("Toont alles over dit item")
        .contextMenu {
            VaultItemActionButtons(
                item: item,
                movesFrom: folder,
                onEdit: { actions.edit(item) },
                onRequestConfirmation: { actions.requestConfirmation(item) },
                onDelete: { actions.delete(item) }
            )
        }
        // The spot the dragged card will take stays visible but faint.
        .opacity(isDragging && drag == .item(item.id) ? 0.35 : 1)
        .vaultDraggable(.item(item.id), in: dragSpace)
        .onDrop(of: [.text], delegate: VaultItemDropDelegate(itemID: item.id, drag: drag, order: $liveItems, lastSwap: $lastSwap, onDrop: endDrag))
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.items.isEmpty {
            emptyMessage(icon: .iconFolderSolid, title: VaultMessages.emptyTitle, message: VaultMessages.emptyMessage, button: "Bewijs toevoegen") {
                actions.add(folder)
            }
        } else if !filter.searchText.isEmpty || filter.narrowsDown {
            emptyMessage(icon: .iconSearch, title: VaultMessages.noResultsTitle, message: VaultMessages.noResultsMessage, button: "Filters wissen") {
                filter = VaultFilter()
            }
        } else if let folder {
            emptyMessage(icon: .iconFolderSolid, title: "\(folder.name) is nog leeg", message: VaultMessages.emptyFolderMessage, button: "Bewijs toevoegen") {
                actions.add(folder)
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
}
