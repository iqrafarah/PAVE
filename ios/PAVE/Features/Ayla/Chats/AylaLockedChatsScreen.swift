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
    /// Whether there is a PIN could not be checked.
    @State private var checkFailed = false
    @State private var renaming: AylaConversation?
    @State private var newTitle = ""
    @State private var deleting: AylaConversation?

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
                } else if checkFailed {
                    VStack(spacing: 12) {
                        PaveInlineError(message: AylaMessages.pinCheckFailed)
                        Button("Opnieuw proberen") { Task { await checkPin() } }
                            .textStyle(.link)
                            .foregroundStyle(Color.paveAccent)
                            .frame(minHeight: 44)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                }
                .paveSheet()
            }
            .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                // Everything deleted: nothing is left here, so back to the chats, as the web goes to the start.
                Button("OK", role: .cancel) { if notice == AylaMessages.accountPinDeleted { dismiss() } }
            }
            .alert("Naam wijzigen", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Naam", text: $newTitle)
                Button("Bewaren") {
                    if let renaming { locks.model.rename(renaming, to: newTitle) }
                }
                Button("Annuleren", role: .cancel) {}
            }
            .confirmationDialog(
                "Chat verwijderen?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible,
                presenting: deleting
            ) { chat in
                Button("Verwijderen", role: .destructive) { locks.model.delete([chat]) }
            } message: { chat in
                Text(AylaMessages.deleteChatMessage(chat.title))
            }
            .task {
                guard hasPin == nil else { return }
                await checkPin()
            }
        }
        .tint(.paveAccent)
    }

    private func checkPin() async {
        checkFailed = false
        if let exists = await locks.pinExists() {
            hasPin = exists
        } else {
            checkFailed = true
        }
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
                            newTitle = chat.title
                            renaming = chat
                        } label: {
                            Label("Naam wijzigen", image: .iconPencil)
                        }
                        Button {
                            Task { _ = await locks.unlock(chat) }
                        } label: {
                            Label { Text(AylaMessages.unlockMenu) } icon: { Image(.iconLockOpenSolid) }
                        }
                        Button(role: .destructive) {
                            deleting = chat
                        } label: {
                            Label("Verwijderen", image: .iconTrash)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}
