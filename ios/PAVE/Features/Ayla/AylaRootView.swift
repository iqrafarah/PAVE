import PAVECore
import SwiftUI

/// Ayla with her chats. On a wide screen (the open iPhone Duo held sideways, an iPad) the chats are a column
/// next to the chat and the chat button shows or hides it; when iPhone Duo is partly folded, both columns are shown
/// so nothing sits in the fold. Everywhere else, including the open iPhone Duo held upright, the chat button opens
/// the chats as a page of their own, so neither the chats nor the conversation gets squeezed.
struct AylaRootView: View {
    @Bindable var model: AylaChatModel
    let onShowMenu: (() -> Void)?
    /// True on a wide screen: the open iPhone Duo held sideways, or an iPad.
    var isWide = false
    @Binding var showsChats: Bool

    @State private var isSelectingInColumn = false
    /// For the plan around the Dynamic Island: the top safe area and width of the screen, and whether the chat asks
    /// the plan to step aside (while talking).
    @State private var topInset: CGFloat = 0
    @State private var screenWidth: CGFloat = 0
    /// The status column on the right of the closed iPhone Duo.
    @State private var trailingInset: CGFloat = 0
    @State private var planIslandHidden = false
    /// The width of the chats column on a wide screen, dragged by its edge.
    @AppStorage("aylaChatsColumnWidth") private var columnWidth = 300.0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ProfileModel.self) private var profile: ProfileModel?

    /// The chats column follows `showsChats`, so the rail and the column always agree.
    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(get: { showsChats ? .all : .detailOnly }, set: { showsChats = $0 != .detailOnly })
    }

    private var island: CGRect? {
        isWide ? nil : DynamicIslandFrame.frame(topInset: topInset, width: screenWidth)
    }

    /// The camera in the column on the right of the closed iPhone Duo.
    private var sideIsland: CGRect? {
        isWide ? nil : DynamicIslandFrame.sideFrame(topInset: topInset, trailingInset: trailingInset, width: screenWidth)
    }

    var body: some View {
        Group {
            if isWide {
                splitLayout
            } else {
                stackLayout
            }
        }
        .environment(\.plansInIsland, island != nil || sideIsland != nil)
        .onGeometryChange(for: [CGFloat].self) { [$0.size.width, $0.safeAreaInsets.top, $0.safeAreaInsets.trailing] } action: { values in
            screenWidth = values[0]
            topInset = values[1]
            trailingInset = values[2]
        }
        .onPreferenceChange(PlanIslandHiddenKey.self) { planIslandHidden = $0 }
        // Above the header, so unfolding it never slides under Ayla's buttons.
        .overlay(alignment: .top) {
            if let island, !showsChats, !planIslandHidden {
                PlanIslandOverlay(chat: model, island: island, screenWidth: screenWidth)
                    .ignoresSafeArea()
            } else if let sideIsland, !showsChats, !planIslandHidden {
                // The whole screen, column included: the island grows out of the camera in it.
                PlanIslandOverlay(chat: model, island: sideIsland, screenWidth: screenWidth + trailingInset, isSide: true)
                    .ignoresSafeArea()
            }
        }
        // The locked chats hide again when PAVE goes to the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.showsLockedChats = false }
        }
    }

    private var stackLayout: some View {
        NavigationStack {
            chat
                .navigationDestination(isPresented: $showsChats) {
                    AylaChatsScreen(
                        list: model.conversationList,
                        currentID: model.conversationID,
                        isLoading: model.isLoadingList || (model.isAvailable && !model.hasLoadedList),
                        hasFailed: model.listFailed,
                        canLoadMore: model.canLoadMore,
                        pendingDeletion: model.pendingDeletion.count,
                        actions: listActions,
                        onNew: startNewConversation
                    )
                    .alert("Chats", isPresented: chatsProblemBinding) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(model.chatsProblem ?? "")
                    }
                }
        }
    }

    private var splitLayout: some View {
        GeometryReader { proxy in
            NavigationSplitView(columnVisibility: columnVisibility) {
                AylaChatList(
                    list: model.conversationList,
                    currentID: model.conversationID,
                    isLoading: model.isLoadingList || (model.isAvailable && !model.hasLoadedList),
                    hasFailed: model.listFailed,
                    canLoadMore: model.canLoadMore,
                    pendingDeletion: model.pendingDeletion.count,
                    isSelecting: $isSelectingInColumn,
                    actions: listActions
                )
                .padding(.horizontal, 12)
                .background(Color.canvas)
                .alert("Chats", isPresented: chatsProblemBinding) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.chatsProblem ?? "")
                }
                .overlay(alignment: .trailing) {
                    AylaColumnResizeHandle(width: $columnWidth)
                        .offset(x: 10)
                }
                .navigationSplitViewColumnWidth(min(max(columnWidth, AylaColumnResizeHandle.range.lowerBound), AylaColumnResizeHandle.range.upperBound))
                .scrollEdgeEffectStyle(.soft, for: .top)
                .toolbar(removing: .sidebarToggle)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        PaveTitle("Chats")
                            .offset(y: 4)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if isSelectingInColumn {
                            Button("Klaar") { withAnimation(.snappy) { isSelectingInColumn = false } }
                        } else {
                            AylaChatsMoreMenu {
                                withAnimation(.snappy) { isSelectingInColumn = true }
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if !isSelectingInColumn {
                            Button(action: startNewConversation) {
                                Image(.iconCompose)
                                    .renderingMode(.template)
                                    .foregroundStyle(Color.ink)
                            }
                            .accessibilityLabel("Nieuw gesprek")
                        }
                    }
                }
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
            } detail: {
                chat
            }
            .toolbar(removing: .sidebarToggle)
            .onChange(of: proxy.foldSplit() != nil, initial: true) { _, isFolded in
                if isFolded { showsChats = true }
            }
        }
    }

    private var chat: some View {
        AylaChatScreen(model: model, onShowMenu: onShowMenu, onShowChats: toggleChats)
    }

    private var listActions: AylaChatListActions {
        AylaChatListActions(
            open: open,
            togglePin: model.togglePin,
            rename: model.rename,
            delete: model.delete,
            undoDeletion: model.undoDeletion,
            refresh: model.refreshConversations,
            loadMore: model.loadMoreConversations,
            search: model.searchMessages,
            preview: model.preview,
            projects: AylaProjectActions(
                create: { await model.createProject(name: $0, instructions: $1, icon: $2, color: $3) },
                update: { await model.updateProject($0) },
                togglePin: model.toggleProjectPin,
                delete: model.deleteProject,
                newChat: startNewConversation(in:),
                move: { model.move($0, to: $1) },
                open: openProject
            ),
            locks: AylaLockActions(
                showsLocked: model.showsLockedChats,
                lock: { await model.setLocked(true, $0) },
                unlock: { await model.setLocked(false, $0) },
                pinExists: model.chatPinExists,
                setPin: model.setChatPin,
                checkPin: model.checkChatPin,
                resetPin: model.resetChatPin,
                relock: { model.showsLockedChats = false },
                model: model
            ),
            retention: AylaRetentionActions(
                accountExpiry: profile?.retention?.chatExpiry ?? ChatExpiry(),
                archive: { model.setArchived(true, $0) },
                setExpiry: { model.setExpiry($1, $0) }
            )
        )
    }

    private var chatsProblemBinding: Binding<Bool> {
        Binding(get: { model.chatsProblem != nil }, set: { if !$0 { model.chatsProblem = nil } })
    }

    /// The start page of a project, in the place of the chat; on a narrow screen the chats page closes for it.
    private func openProject(_ project: AylaProject) {
        model.openPage(of: project)
        if !isWide { showsChats = false }
    }

    private func toggleChats() {
        Task { await model.refreshConversations() }
        withAnimation { showsChats.toggle() }
    }

    private func open(_ conversation: AylaConversation) {
        if !isWide { showsChats = false }
        guard conversation.id != model.conversationID else { return }
        Task { await model.open(conversation) }
    }

    private func startNewConversation() {
        model.newConversation()
        if !isWide { showsChats = false }
    }

    /// "Nieuwe chat in project": the next question starts a chat inside the project.
    private func startNewConversation(in project: AylaProject) {
        model.newConversation(in: project)
        if !isWide { showsChats = false }
    }
}

#Preview {
    @Previewable @State var showsChats = false
    AylaRootView(model: AylaChatModel(service: nil), onShowMenu: {}, showsChats: $showsChats)
        .environment(AylaMemoryModel(service: nil))
}
