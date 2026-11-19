import PAVECore
import SwiftUI

/// "Vergrendelde chats" (web /vergrendeld): first the PIN, then the locked chats. They stay visible until "Nu
/// vergrendelen" or until PAVE closes. "Pincode vergeten?" deletes every locked chat for good, after asking.
struct AylaLockedChatsScreen: View {
    @Environment(\.dismiss) private var dismiss
    let chats: [AylaConversation]
    let locks: AylaLockActions
    let onOpen: (AylaConversation) -> Void

    @State private var hasPin: Bool?
    @State private var confirmsReset = false

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
                    AylaChatPinView(mode: .enter, onPin: locks.checkPin) { confirmsReset = true }
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
            .confirmationDialog(AylaMessages.pinResetQuestion, isPresented: $confirmsReset, titleVisibility: .visible) {
                Button(AylaMessages.pinResetConfirm, role: .destructive) {
                    Task {
                        if await locks.resetPin() { hasPin = false }
                    }
                }
            } message: {
                Text(AylaMessages.pinResetBody)
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
                        Button(AylaMessages.unlockMenu, systemImage: "lock.open") {
                            Task { _ = await locks.unlock(chat) }
                        }
                        .tint(.paveAccent)
                    }
                    .contextMenu {
                        Button(AylaMessages.unlockMenu, systemImage: "lock.open") {
                            Task { _ = await locks.unlock(chat) }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}
