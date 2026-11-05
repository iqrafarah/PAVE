import PAVECore
import SwiftUI

/// Ayla with the conversations as a sidebar. On iPhone and the outer display of iPhone Duo the sidebar
/// folds away behind the menu button; on the inner display of iPhone Duo and on iPad it sits next to the chat.
/// When iPhone Duo is partly folded, both columns are shown so nothing sits in the fold.
struct AylaRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model: AylaChatModel
    @State private var selection: String?
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @State private var compactColumn = NavigationSplitViewColumn.detail

    init(service: (any AylaService)?) {
        _model = State(initialValue: AylaChatModel(service: service))
    }

    var body: some View {
        GeometryReader { proxy in
            NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
                ConversationSidebar(
                    conversations: model.conversations,
                    selection: $selection,
                    onNew: startNewConversation,
                    onSignOut: appState.signOut
                )
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
            } detail: {
                AylaChatScreen(model: model, onShowConversations: toggleConversations)
            }
            .toolbar(removing: .sidebarToggle)
            .onChange(of: proxy.foldSplit() != nil, initial: true) { _, isFolded in
                if isFolded { columnVisibility = .all }
            }
        }
        .tint(.brandGreen)
        .task { await model.start() }
        .onChange(of: selection) { _, id in
            guard let id, id != model.conversationID,
                  let conversation = model.conversations.first(where: { $0.id == id }) else { return }
            compactColumn = .detail
            Task { await model.open(conversation) }
        }
        .onChange(of: model.conversationID) { _, id in
            if selection != id { selection = id }
        }
    }

    /// The menu button: on iPhone it shows the list, on wider screens it shows or hides the sidebar.
    private func toggleConversations() {
        if sizeClass == .regular {
            withAnimation { columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly }
        } else {
            compactColumn = .sidebar
        }
    }

    private func startNewConversation() {
        model.newConversation()
        selection = nil
        compactColumn = .detail
    }
}

#Preview {
    AylaRootView(service: nil)
        .environment(AppState())
}
