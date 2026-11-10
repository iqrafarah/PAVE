import PAVECore
import SwiftUI

/// All chats with Ayla on iPhone, opened with the chat button at the top right (Figma "Chats"). The back button
/// returns to the conversation; "Nieuw gesprek" sits at the bottom, within reach of your thumb. The button with three
/// dots at the top right holds "Selecteren", to pin or delete several chats at once.
struct AylaChatsScreen: View {
    let list: AylaConversationList
    let currentID: String?
    let isLoading: Bool
    let hasFailed: Bool
    let canLoadMore: Bool
    let pendingDeletion: Int
    let actions: AylaChatListActions
    let onNew: () -> Void

    @State private var isSelecting = false

    var body: some View {
        AylaChatList(
            list: list,
            currentID: currentID,
            isLoading: isLoading,
            hasFailed: hasFailed,
            canLoadMore: canLoadMore,
            pendingDeletion: pendingDeletion,
            isSelecting: $isSelecting,
            actions: actions
        )
            .padding(.horizontal, 15)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 12) {
                if !isSelecting {
                    PaveActionButton(title: "Nieuw gesprek", icon: .iconCompose, style: .glass, cornerRadius: 25, action: onNew)
                        .padding(.horizontal, 26)
                        .frame(maxWidth: 560)
                }
            }
            .background(Color.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    PaveTitle("Chats")
                        .offset(y: 4)
                }
                if !list.conversations.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        if isSelecting {
                            Button("Klaar") {
                                withAnimation(.snappy) { isSelecting = false }
                            }
                        } else {
                            AylaChatsMoreMenu {
                                withAnimation(.snappy) { isSelecting = true }
                            }
                        }
                    }
                }
            }
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AylaChatsScreen(
            list: AylaConversationList(conversations: [AylaConversation(id: "1", title: "Softskills uitwerken", updatedAt: .now)], canPin: false),
            currentID: nil,
            isLoading: false,
            hasFailed: false,
            canLoadMore: false,
            pendingDeletion: 0,
            actions: AylaChatListActions(
                open: { _ in }, togglePin: { _ in }, rename: { _, _ in }, delete: { _ in }, undoDeletion: {},
                refresh: {}, loadMore: {}, search: { _ in [] }, preview: { _ in [] }
            ),
            onNew: {}
        )
    }
}
