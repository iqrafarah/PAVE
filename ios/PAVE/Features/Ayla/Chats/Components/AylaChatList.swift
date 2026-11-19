import PAVECore
import SwiftUI

/// What the chats list can ask the chat model to do. The list itself never talks to the server.
struct AylaChatListActions {
    var open: (AylaConversation) -> Void
    var togglePin: ([AylaConversation]) -> Void
    var rename: (AylaConversation, String) -> Void
    var delete: ([AylaConversation]) -> Void
    var undoDeletion: () -> Void
    var refresh: () async -> Void
    var loadMore: () async -> Void
    var search: (String) async -> [(hit: AylaSearchHit, conversation: AylaConversation)]
    var preview: (AylaConversation) async -> [AylaStoredMessage]
    var projects: AylaProjectActions?
    var locks: AylaLockActions?
}

/// "Projecten": folders for chats with Ayla's own instructions (web useAylaProjects).
struct AylaProjectActions {
    var create: (_ name: String, _ instructions: String) async -> AylaProject?
    var update: (AylaProject) async -> Bool
    var togglePin: (AylaProject) -> Void
    var delete: (AylaProject) -> Void
    var newChat: (AylaProject) -> Void
    var move: (AylaConversation, AylaProject?) -> Void
}

/// "Vergrendelde chats": one PIN of four digits for every locked chat (web useAylaChatLock).
struct AylaLockActions {
    /// The locked chats show after the right PIN, until "Nu vergrendelen".
    var showsLocked: Bool
    var lock: (AylaConversation) async -> Bool
    var unlock: (AylaConversation) async -> Bool
    var pinExists: () async -> Bool?
    var setPin: (String) async -> String?
    var checkPin: (String) async -> String?
    var resetPin: () async -> Bool
    var relock: () -> Void
}

/// The chats with Ayla (Figma "Chats"), as in Mail and ChatGPT: search, then pinned and by when they were last used.
/// Swipe a chat to pin it (from the left) or to rename or delete it (from the right); press and hold it to see its
/// last messages and the same actions. "Selecteren" lets you pin or delete several at once. A deleted chat can be
/// brought back for a few seconds. Pull down to refresh; older chats load when you reach the end.
/// On iPhone it is a page of its own; on a wide screen it is the column next to the chat.
struct AylaChatList: View {
    let list: AylaConversationList
    let currentID: String?
    let isLoading: Bool
    let hasFailed: Bool
    let canLoadMore: Bool
    /// How many chats were just deleted and can still be brought back.
    let pendingDeletion: Int
    @Binding var isSelecting: Bool
    let actions: AylaChatListActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var search = ""
    @State private var hits: [(hit: AylaSearchHit, conversation: AylaConversation)] = []
    @State private var renaming: AylaConversation?
    @State private var newTitle = ""
    @State private var selection = Set<String>()
    @State private var openProjects = Set<String>()
    @State private var projectEditor: ProjectEditing?
    @State private var lockTarget: AylaConversation?
    @State private var pinSetupFor: AylaConversation?
    @State private var showsLockedChats = false
    /// The chat being dragged, from the moment iOS lifts it until it is let go.
    @State private var draggedChat: String?
    /// Where each row is; kept outside SwiftUI's state, so scrolling does not redraw the list.
    @State private var rowFrames = RowFrames()
    @State private var dragEnd: Task<Void, Never>?
    private static let listSpace = "chatList"
    @FocusState private var isSearchFocused: Bool
    @Environment(\.chatSearchRequestedAt) private var searchRequestedAt
    /// The vault, so the search also finds evidence, documents and pictures, as on the web.
    @Environment(VaultModel.self) private var vault: VaultModel?
    @Environment(\.openFromAyla) private var openFromAyla
    @State private var searchTab = PaveSearchTab.all
    @State private var previewURL: URL?

    private var isSearching: Bool { !search.trimmingCharacters(in: .whitespaces).isEmpty }



    private enum ProjectEditing: Identifiable {
        case new
        case edit(AylaProject)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let project): project.id
            }
        }
    }

    /// One flat list of headers, projects and chats: Vastgezet, then Projecten, then the rest by when it was used, as on
    /// the web.
    private enum Item: Identifiable {
        case header(String)
        case chat(AylaConversation)
        case projectsHeader
        case project(AylaProject)
        case projectChat(AylaConversation)
        case locked(Int)

        /// A chat gets a fresh row when it is pinned or unpinned or moves into a project: the row you swiped is still
        /// busy closing its swipe buttons and shows no text for a moment, so reusing it in the new place looked like a
        /// glitch.
        var id: String {
            switch self {
            case .header(let title): "header-\(title)"
            case .chat(let conversation): conversation.isPinned ? "\(conversation.id)-pinned" : conversation.id
            case .projectsHeader: "projects"
            case .project(let project): "project-\(project.id)"
            case .projectChat(let conversation): "\(conversation.id)-in-\(conversation.projectID ?? "")"
            case .locked: "locked"
            }
        }
    }

    private var items: [Item] {
        let sections = list.sections()
        let pinned = sections.filter { $0.kind == .pinned }
        let rest = sections.filter { $0.kind != .pinned }
        var items = pinned.flatMap { [Item.header($0.title)] + $0.conversations.map(Item.chat) }
        let hasLocked = list.canLock && actions.locks != nil && !list.locked.isEmpty
        if list.canUseProjects, actions.projects != nil {
            items.append(.projectsHeader)
            for project in list.orderedProjects {
                items.append(.project(project))
                if openProjects.contains(project.id) {
                    items += list.chats(in: project.id).map(Item.projectChat)
                }
            }
        }
        // As on the web: the last entry of Projecten, like a folder of its own, above the other chats.
        if hasLocked { items.append(.locked(list.locked.count)) }
        items += rest.flatMap { [Item.header($0.title)] + $0.conversations.map(Item.chat) }
        return items
    }

    private var selected: [AylaConversation] {
        list.conversations.filter { selection.contains($0.id) }
    }

    var body: some View {
        List(selection: $selection) {
            if !isSelecting {
                PaveSearchField(text: $search, prompt: "Zoeken in chats", isFocused: $isSearchFocused)
                    .padding(.bottom, 8)
                    .plainRow()
                    .selectionDisabled()
            }

            if isSearching, !isSelecting {
                searchResults
            } else if list.conversations.isEmpty, list.projects.isEmpty {
                emptyState
            } else {
                ForEach(items) { item in
                    itemRow(item)
                        // Where each row is, so a chat let go over the list lands in the right place.
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.listSpace)) } action: { frame in
                            rowFrames.frames[item.id] = frame
                        }
                }
                if canLoadMore {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .plainRow()
                        .selectionDisabled()
                        .task { await actions.loadMore() }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
        .coordinateSpace(.named(Self.listSpace))
        // A list takes no drops on its own rows, so while a chat is dragged a clear layer over it catches the drop and
        // the place decides where it goes (tested in the simulator: drops on rows inside a List never arrive).
        .overlay {
            Color.clear
                .contentShape(.rect)
                .allowsHitTesting(draggedChat != nil)
                .dropDestination(for: String.self) { ids, point in
                    defer { draggedChat = nil }
                    guard let id = ids.first else { return false }
                    return drop(id, at: point)
                } isTargeted: { isOver in
                    if isOver { dragEnd?.cancel() } else { endDragSoon() }
                }
                // If a drag ended somewhere the layer did not hear, the first tap clears it.
                .onTapGesture { draggedChat = nil }
        }
        .refreshable { await actions.refresh() }
        // Asked for with ⌘K: only a fresh request, not one from earlier.
        .task(id: searchRequestedAt) {
            guard let searchRequestedAt, Date.now.timeIntervalSince(searchRequestedAt) < 2, !isSelecting else { return }
            try? await Task.sleep(for: .milliseconds(300))
            isSearchFocused = true
        }
        .safeAreaInset(edge: .bottom, spacing: 12) {
            VStack(spacing: 10) {
                if pendingDeletion > 0 {
                    AylaUndoBar(count: pendingDeletion) {
                        PaveHaptics.success()
                        withAnimation(listAnimation) { actions.undoDeletion() }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if isSelecting {
                    selectionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 11)
            .animation(.snappy, value: pendingDeletion)
            .animation(.snappy, value: isSelecting)
        }
        .task(id: search) {
            guard isSearching else {
                hits = []
                return
            }
            // Waits until typing pauses, so not every letter asks the server.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            hits = await actions.search(search)
        }
        .onChange(of: isSelecting) { _, selecting in
            PaveHaptics.tap(.light)
            if !selecting { selection = [] }
        }
        .onChange(of: selection) { old, new in
            if !old.isEmpty || !new.isEmpty { PaveHaptics.selection() }
        }
        .sheet(item: $projectEditor) { editing in
            projectEditorSheet(editing)
        }
        .sheet(isPresented: $showsLockedChats) {
            if let locks = actions.locks {
                AylaLockedChatsScreen(chats: list.locked, locks: locks, onOpen: actions.open)
            }
        }
        .sheet(item: $pinSetupFor) { conversation in
            AylaChatPinView(mode: .create) { pin in
                guard let locks = actions.locks else { return AylaMessages.pinCodeFailed }
                if let failure = await locks.setPin(pin) { return failure }
                pinSetupFor = nil
                _ = await locks.lock(conversation)
                return nil
            }
            .background(Color.canvas.ignoresSafeArea())
            .presentationDetents([.large])
        }
        .confirmationDialog(AylaMessages.lockQuestion, isPresented: isLocking, titleVisibility: .visible, presenting: lockTarget) { conversation in
            Button(AylaMessages.lockMenu) { lock(conversation) }
        } message: { _ in
            Text(AylaMessages.lockBody)
        }
        .alert("Naam wijzigen", isPresented: isRenaming) {
            TextField("Naam", text: $newTitle)
            Button("Bewaren") {
                if let renaming {
                    PaveHaptics.success()
                    actions.rename(renaming, newTitle)
                }
            }
            Button("Annuleren", role: .cancel) {}
        }
    }

    // MARK: Rows

    private func row(_ conversation: AylaConversation) -> some View {
        AylaChatRow(conversation: conversation, isCurrent: conversation.id == currentID && !isSelecting) {
            actions.open(conversation)
        }
        // While selecting, a tap selects the row instead of opening it.
        .allowsHitTesting(!isSelecting)
        .tag(conversation.id)
        .plainRow()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if list.canPin {
                Button {
                    pin([conversation])
                } label: {
                    Label { Text(conversation.isPinned ? "Losmaken" : "Vastzetten") } icon: { Image(systemName: conversation.isPinned ? "pin.slash.fill" : "pin.fill") }
                }
                .tint(.paveAccent)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete([conversation])
            } label: {
                Label("Verwijderen", image: .iconTrash)
            }
            // Red, not the app's green tint.
            .tint(.red)
            Button {
                startRenaming(conversation)
            } label: {
                Label("Naam wijzigen", image: .iconPencil)
            }
            .tint(.inkMuted)
        }
        .contextMenu {
            menu(for: conversation)
        } preview: {
            AylaChatPreview(title: conversation.title) { await actions.preview(conversation) }
        }
        // Hold a chat and drag it, as on the web: onto a project to put it there, onto Vastgezet to pin it, among the
        // other chats to take it out of its project and unpin it.
        .draggable(conversation.id) {
            AylaChatDragPreview(conversation: conversation)
                .onAppear {
                    dragEnd?.cancel()
                    draggedChat = conversation.id
                    PaveHaptics.tap(.light)
                }
        }
        .accessibilityActions {
            menu(for: conversation)
        }
    }

    @ViewBuilder
    private func menu(for conversation: AylaConversation) -> some View {
        Button {
            startRenaming(conversation)
        } label: {
            Label("Naam wijzigen", image: .iconPencil)
        }
        if list.canPin {
            Button {
                pin([conversation])
            } label: {
                Label { Text(conversation.isPinned ? "Losmaken" : "Vastzetten") } icon: { Image(systemName: conversation.isPinned ? "pin.slash.fill" : "pin.fill") }
            }
        }
        if let projects = actions.projects, list.canUseProjects {
            Menu {
                ForEach(list.orderedProjects.filter { $0.id != conversation.projectID }) { project in
                    Button {
                        projects.move(conversation, project)
                        openProjects.insert(project.id)
                    } label: {
                        Label { Text(project.name) } icon: { Image(.iconFolderSolid) }
                    }
                }
                if list.projects.isEmpty {
                    Text(AylaMessages.moveEmpty)
                }
                if conversation.projectID != nil {
                    Divider()
                    Button { projects.move(conversation, nil) } label: { Label { Text(AylaMessages.removeFromProject) } icon: { Image(.iconXMark) } }
                }
                Divider()
                Button { projectEditor = .new } label: { Label { Text(AylaMessages.newProject) } icon: { Image(.iconFolderPlusSolid) } }
            } label: {
                Label { Text(AylaMessages.moveToProject) } icon: { Image(.iconFolderSolid) }
            }
        }
        if actions.locks != nil, list.canLock {
            Button {
                lockTarget = conversation
            } label: {
                Label { Text(AylaMessages.lockMenu) } icon: { Image(.iconLockClosedSolid) }
            }
        }
        Button {
            isSelecting = true
            selection = [conversation.id]
        } label: {
            Label("Selecteren", systemImage: "checkmark.circle.fill")
        }
        Button(role: .destructive) {
            delete([conversation])
        } label: {
            Label("Verwijderen", image: .iconTrash)
        }
    }

    /// Pin or delete the selected chats.
    private var selectionBar: some View {
        let chosen = selected
        let allPinned = !chosen.isEmpty && chosen.allSatisfy(\.isPinned)
        return HStack(spacing: 10) {
            if list.canPin {
                Button {
                    pin(chosen)
                    isSelecting = false
                } label: {
                    Label { Text(allPinned ? "Losmaken" : "Vastzetten") } icon: { Image(systemName: allPinned ? "pin.slash.fill" : "pin.fill") }
                        .textStyle(.action)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .contentShape(.capsule)
                }
                .buttonStyle(.pave)
                .foregroundStyle(Color.paveAccent)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            Button {
                delete(chosen)
                isSelecting = false
            } label: {
                Label(chosen.count > 1 ? "Verwijder \(chosen.count)" : "Verwijderen", image: .iconTrash)
                    .textStyle(.action)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(.capsule)
            }
            .buttonStyle(.pave)
            .foregroundStyle(.white)
            .background(Color.red, in: .capsule)
        }
        .disabled(chosen.isEmpty)
        .opacity(chosen.isEmpty ? 0.5 : 1)
    }

    @ViewBuilder
    private var searchResults: some View {
        let needle = search.trimmingCharacters(in: .whitespaces)
        let tabs = PaveSearchTab.available(vaultReady: vault?.state == .ready, projects: list.canUseProjects)
        let titles = (searchTab == .all || searchTab == .chats) ? list.matching(needle).conversations.sorted { $0.updatedAt > $1.updatedAt } : []
        let titleIDs = Set(titles.map(\.id))
        let inMessages = (searchTab == .all || searchTab == .chats) ? hits.filter { !titleIDs.contains($0.conversation.id) } : []
        let projects = searchTab.shows(.projects) ? PaveSearch.projects(list, matching: needle) : []
        let items = searchTab.shows(.items) ? PaveSearch.items(vault, matching: needle) : []
        let files = PaveSearch.files(vault, matching: needle, tab: searchTab)

        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in
                    Button {
                        PaveHaptics.selection()
                        searchTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .textStyle(.caption)
                            .foregroundStyle(searchTab == tab ? Color.white : Color.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 32)
                            .background(searchTab == tab ? Color.paveAccent : Color.paveSurfaceTint, in: .capsule)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pave)
                    .accessibilityAddTraits(searchTab == tab ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 12)
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 4)
        .plainRow()
        .selectionDisabled()

        if titles.isEmpty, inMessages.isEmpty, projects.isEmpty, items.isEmpty, files.isEmpty {
            Text("Geen resultaten voor “\(needle)”.")
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .plainRow()
                .selectionDisabled()
        }
        ForEach(titles) { conversation in
            AylaSearchResultRow(
                icon: .chat, title: conversation.title, subtitle: list.project(of: conversation)?.name,
                date: conversation.updatedAt, search: needle
            ) { actions.open(conversation) }
            .plainRow()
            .selectionDisabled()
        }
        ForEach(inMessages, id: \.hit.id) { found in
            AylaSearchResultRow(
                icon: .chat, title: found.conversation.title, subtitle: found.hit.snippet,
                date: found.conversation.updatedAt, search: needle
            ) { actions.open(found.conversation) }
            .plainRow()
            .selectionDisabled()
        }
        ForEach(projects) { project in
            AylaSearchResultRow(
                icon: .project, title: project.name, subtitle: project.instructions, date: project.updatedAt, search: needle
            ) {
                search = ""
                openProjects.insert(project.id)
            }
            .plainRow()
            .selectionDisabled()
        }
        ForEach(items) { item in
            AylaSearchResultRow(
                icon: .item, title: item.title, subtitle: [item.organisationName, item.period].compactMap { $0 }.joined(separator: " · "),
                date: item.createdAt, search: needle
            ) { openFromAyla?(AylaReply.Navigation(screen: .vaultItem, itemId: item.id)) }
            .plainRow()
            .selectionDisabled()
        }
        ForEach(files, id: \.file.id) { found in
            AylaSearchResultRow(
                icon: .file(.init(fileName: found.file.name)), title: found.file.name, subtitle: found.item.title,
                date: found.item.createdAt, search: needle
            ) { openFile(found.file) }
            .plainRow()
            .selectionDisabled()
        }
        Color.clear
            .frame(height: 1)
            .vaultQuickLook($previewURL)
            .plainRow()
            .selectionDisabled()
    }

    private func openFile(_ file: VaultItem.File) {
        guard let vault else { return }
        Task {
            guard let data = await vault.data(of: file), let url = VaultPreviewFile.url(for: data, named: file.name) else {
                PaveHaptics.error()
                return
            }
            previewURL = url
        }
    }


    @ViewBuilder
    private var emptyState: some View {
        if isLoading {
            // Placeholder rows in the shape of the real ones while the list loads.
            ForEach(0..<6, id: \.self) { index in
                AylaChatRow(conversation: AylaConversation(id: "loading-\(index)", title: "Gesprek met Ayla over je stage", updatedAt: .now), isCurrent: false) {}
                    .redacted(reason: .placeholder)
                    .disabled(true)
                    .plainRow()
                    .selectionDisabled()
            }
            .accessibilityHidden(true)
        } else if hasFailed {
            VStack(spacing: 14) {
                Text(AylaMessages.chatsUnavailable)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                Button("Opnieuw proberen") {
                    Task { await actions.refresh() }
                }
                .textStyle(.link)
                .foregroundStyle(Color.paveAccent)
                .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .plainRow()
            .selectionDisabled()
        } else {
            PaveEmptyState(icon: .iconChat, title: "Nog geen chats", message: "Je gesprekken met Ayla komen hier te staan, ook die je op web begint.")
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .plainRow()
                .selectionDisabled()
        }
    }

    @ViewBuilder
    private func itemRow(_ item: Item) -> some View {
        switch item {
        case .header(let title):
            header(title)
                .selectionDisabled()
        case .chat(let conversation):
            row(conversation)
        case .projectsHeader:
            projectsHeader
                .selectionDisabled()
        case .project(let project):
            projectRow(project)
                .selectionDisabled()
        case .projectChat(let conversation):
            row(conversation)
                .padding(.leading, 22)
        case .locked(let count):
            lockedRow(count)
                .selectionDisabled()
        }
    }

    // MARK: Projects

    private var projectsHeader: some View {
        HStack {
            Text(AylaMessages.projects)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                projectEditor = .new
            } label: {
                Image(.iconPlus)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(16)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel(AylaMessages.newProject)
        }
        .padding(.leading, 12)
        .padding(.top, 14)
        .plainRow()
    }

    private func projectRow(_ project: AylaProject) -> some View {
        let isOpen = openProjects.contains(project.id)
        return AylaProjectRow(
            project: project,
            count: list.chats(in: project.id).count,
            isOpen: isOpen
        ) {
            PaveHaptics.selection()
            withAnimation(listAnimation) {
                if isOpen { openProjects.remove(project.id) } else { openProjects.insert(project.id) }
            }
        }
        .plainRow()
        .contextMenu { projectMenu(project) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                actions.projects?.delete(project)
            } label: {
                Label(AylaMessages.projectDelete, image: .iconTrash)
            }
            .tint(.red)
            Button {
                projectEditor = .edit(project)
            } label: {
                Label(AylaMessages.projectSettings, image: .iconPencil)
            }
            .tint(.inkMuted)
        }
        .accessibilityActions { projectMenu(project) }
    }

    @ViewBuilder
    private func projectMenu(_ project: AylaProject) -> some View {
        Button { actions.projects?.newChat(project) } label: { Label { Text(AylaMessages.projectNewChat) } icon: { Image(.iconCompose).renderingMode(.template) } }
        Button { projectEditor = .edit(project) } label: { Label { Text(AylaMessages.projectSettings) } icon: { Image(.iconPencil) } }
        Button {
            actions.projects?.togglePin(project)
        } label: {
            Label { Text(project.isPinned ? "Losmaken" : "Vastzetten") } icon: { Image(systemName: project.isPinned ? "pin.slash.fill" : "pin.fill") }
        }
        Button(role: .destructive) { actions.projects?.delete(project) } label: { Label { Text(AylaMessages.projectDelete) } icon: { Image(.iconTrash) } }
    }

    @ViewBuilder
    private func projectEditorSheet(_ editing: ProjectEditing) -> some View {
        switch editing {
        case .new:
            AylaProjectEditor(project: nil) { name, instructions in
                guard let project = await actions.projects?.create(name, instructions) else { return false }
                openProjects.insert(project.id)
                return true
            }
        case .edit(let project):
            AylaProjectEditor(project: project) { name, instructions in
                var changed = project
                changed.name = name
                changed.instructions = instructions
                return await actions.projects?.update(changed) ?? false
            } onDelete: {
                actions.projects?.delete(project)
            }
        }
    }

    /// Where a dragged chat was let go decides what happens to it; the list keeps its own order (pinned, then by date).
    private func drop(_ id: String, at point: CGPoint) -> Bool {
        guard let chat = list.visible.first(where: { $0.id == id }) else { return false }
        let shown = items
        // The row under the finger, or else the nearest row above it.
        let under = shown.last { item in
            guard let frame = rowFrames.frames[item.id] else { return false }
            return frame.minY <= point.y
        }
        let pinnedTitle = "Vastgezet"

        enum Target { case pinned, project(AylaProject), plain, nothing }
        let target: Target = switch under {
        case .header(let title) where title == pinnedTitle: .pinned
        case .chat(let conversation) where conversation.isPinned: .pinned
        case .project(let project): .project(project)
        case .projectChat(let conversation): list.project(of: conversation).map(Target.project) ?? .plain
        case .projectsHeader, .locked, nil: .nothing
        default: .plain
        }

        switch target {
        case .pinned:
            guard !chat.isPinned, list.canPin else { return false }
            pin([chat])
        case .project(let project):
            guard chat.projectID != project.id else { return false }
            if chat.isPinned, list.canPin { pin([chat]) }
            actions.projects?.move(chat, project)
            withAnimation(listAnimation) { _ = openProjects.insert(project.id) }
        case .plain:
            guard chat.isPinned || chat.projectID != nil else { return false }
            if chat.isPinned, list.canPin { pin([chat]) }
            if chat.projectID != nil { actions.projects?.move(chat, nil) }
        case .nothing:
            return false
        }
        PaveHaptics.success()
        return true
    }

    /// Leaving the list ends the drag after a moment, unless the finger comes back over it.
    private func endDragSoon() {
        dragEnd?.cancel()
        dragEnd = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            draggedChat = nil
        }
    }

    // MARK: Locked chats

    private func lockedRow(_ count: Int) -> some View {
        Button {
            PaveHaptics.selection()
            showsLockedChats = true
        } label: {
            HStack(spacing: 10) {
                Image(.iconLockClosedSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(20)
                    .foregroundStyle(Color.paveAccent)
                Text(AylaMessages.lockedChats)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                Spacer(minLength: 8)
                Text("\(count)")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                Image(.iconChevronRight)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.inkMuted)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .plainRow()
        .accessibilityLabel("\(AylaMessages.lockedChats), \(count)")
    }

    /// Without a PIN yet, you choose one first; then the chat is locked.
    private func lock(_ conversation: AylaConversation) {
        guard let locks = actions.locks else { return }
        Task {
            if await locks.pinExists() == false {
                pinSetupFor = conversation
            } else {
                _ = await locks.lock(conversation)
            }
        }
    }

    private var isLocking: Binding<Bool> {
        Binding(get: { lockTarget != nil }, set: { if !$0 { lockTarget = nil } })
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.inkMuted)
            .padding(.leading, 12)
            .padding(.top, 14)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
            .plainRow()
    }

    // MARK: Actions

    /// At once and without an animation of our own: the list then simply redraws the row in its new place. Waiting or
    /// animating left the row empty for a moment and made it fade in, which looked like a glitch.
    private func pin(_ conversations: [AylaConversation]) {
        guard !conversations.isEmpty else { return }
        PaveHaptics.tap(.medium)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { actions.togglePin(conversations) }
    }

    private func delete(_ conversations: [AylaConversation]) {
        guard !conversations.isEmpty else { return }
        PaveHaptics.tap(.heavy)
        // No animation of our own: a swipe to delete already removes the row, and a second removal makes the list
        // crash.
        actions.delete(conversations)
    }

    /// Only your own actions move rows with an animation; changes from the server simply appear.
    private var listAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.3)
    }

    private func startRenaming(_ conversation: AylaConversation) {
        newTitle = conversation.title
        renaming = conversation
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }
}

/// The places of the rows, read only when a chat is let go.
private final class RowFrames {
    var frames: [String: CGRect] = [:]
}

private extension View {
    /// A row without the list's own background, separator and insets, so the list looks like the rest of PAVE.
    func plainRow() -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    @Previewable @State var isSelecting = false
    AylaChatList(
        list: AylaConversationList(
            conversations: [
                AylaConversation(id: "1", title: "Softskills uitwerken", updatedAt: .now, pinnedAt: .now),
                AylaConversation(id: "2", title: "Cv verbeteren voor loopbaan in de zorg", updatedAt: .now, startedOn: .web),
                AylaConversation(id: "3", title: "Ik wil graag docent ICT worden", updatedAt: .now.addingTimeInterval(-86_400)),
            ],
            canPin: true
        ),
        currentID: "2",
        isLoading: false,
        hasFailed: false,
        canLoadMore: false,
        pendingDeletion: 1,
        isSelecting: $isSelecting,
        actions: AylaChatListActions(
            open: { _ in }, togglePin: { _ in }, rename: { _, _ in }, delete: { _ in }, undoDeletion: {},
            refresh: {}, loadMore: {}, search: { _ in [] }, preview: { _ in [] }
        )
    )
    .padding(.horizontal, 16)
    .background(Color.canvas)
}
