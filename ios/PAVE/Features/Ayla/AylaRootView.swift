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

    /// The chats column follows `showsChats`, so the rail and the column always agree.
    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(get: { showsChats ? .all : .detailOnly }, set: { showsChats = $0 != .detailOnly })
    }

    var body: some View {
        if isWide {
            splitLayout
        } else {
            stackLayout
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
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
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
            preview: model.preview
        )
    }

    private var chatsProblemBinding: Binding<Bool> {
        Binding(get: { model.chatsProblem != nil }, set: { if !$0 { model.chatsProblem = nil } })
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
}

#Preview {
    @Previewable @State var showsChats = false
    AylaRootView(model: AylaChatModel(service: nil), onShowMenu: {}, showsChats: $showsChats)
}
