import PAVECore
import SwiftUI

/// "Vergrendelde chats" (web /vergrendeld): first the PIN, then the locked chats. They stay visible until "Nu
/// vergrendelen" or until PAVE closes. "Pincode vergeten?" resets the PIN with the authenticator app, and the locked chats
/// stay; only without it are they deleted.
struct AylaLockedChatsScreen: View {
    @Environment(\.dismiss) private var dismiss
    let chats: [AylaConversation]
    let locks: AylaLockActions
    let onOpen: (AylaConversation) -> Void

    @State private var hasPin: Bool?
    @State private var recovers = false
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            Group {
                if locks.showsLocked {
                    list
                } else if hasPin == false {
                    AylaChatPinView(mode: .create) { pin in
                        let failure = await locks.setPin(pin)
                        if failure == nil { hasPin = true }
                        return failure
                    }
                } else if hasPin == true {
                    AylaChatPinView(mode: .enter, onPin: locks.checkPin) { recovers = true }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(AylaMessages.lockedChats)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
                if locks.showsLocked {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AylaMessages.lockedRelock) {
                            locks.relock()
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $recovers) {
                AylaAccountPinSheet(purpose: .recover, model: locks.model) { message in
                    notice = message
                    if message == AylaMessages.accountPinDeleted { hasPin = false }
                }
                .paveSheet()
            }
            .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .task {
                guard hasPin == nil else { return }
                hasPin = await locks.pinExists() ?? true
            }
        }
        .tint(.paveAccent)
    }

    @ViewBuilder
    private var list: some View {
        if chats.isEmpty {
            PaveEmptyState(icon: .iconChat, title: AylaMessages.lockedChats, message: AylaMessages.lockedEmpty)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(chats) { chat in
                    AylaChatRow(conversation: chat, isCurrent: false) {
                        onOpen(chat)
                        dismiss()
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            Task { _ = await locks.unlock(chat) }
                        } label: {
                            Label { Text(AylaMessages.unlockMenu) } icon: { Image(.iconLockOpenSolid) }
                        }
                        .tint(.paveAccent)
                    }
                    .contextMenu {
                        Button {
                            Task { _ = await locks.unlock(chat) }
                        } label: {
                            Label { Text(AylaMessages.unlockMenu) } icon: { Image(.iconLockOpenSolid) }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}
