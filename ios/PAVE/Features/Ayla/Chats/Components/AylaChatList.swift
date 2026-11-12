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
    @FocusState private var isSearchFocused: Bool
    @Environment(\.chatSearchRequestedAt) private var searchRequestedAt

    private var isSearching: Bool { !search.trimmingCharacters(in: .whitespaces).isEmpty }

    /// One flat list of headers and chats.
    private enum Item: Identifiable {
        case header(String)
        case chat(AylaConversation)

        /// A chat gets a fresh row when it is pinned or unpinned: the row you swiped is still busy closing its swipe
        /// buttons and shows no text for a moment, so reusing it in the new place looked like a glitch.
        var id: String {
            switch self {
            case .header(let title): "header-\(title)"
            case .chat(let conversation): conversation.isPinned ? "\(conversation.id)-pinned" : conversation.id
            }
        }
    }

    private var items: [Item] {
        list.sections().flatMap { section in
            [Item.header(section.title)] + section.conversations.map(Item.chat)
        }
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
            } else if list.conversations.isEmpty {
                emptyState
            } else {
                ForEach(items) { item in
                    switch item {
                    case .header(let title):
                        header(title)
                            .selectionDisabled()
                    case .chat(let conversation):
                        row(conversation)
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
                    Label(conversation.isPinned ? "Losmaken" : "Vastzetten", systemImage: conversation.isPinned ? "pin.slash.fill" : "pin.fill")
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
                Label(conversation.isPinned ? "Losmaken" : "Vastzetten", systemImage: conversation.isPinned ? "pin.slash.fill" : "pin.fill")
            }
        }
        Button {
            isSelecting = true
            selection = [conversation.id]
        } label: {
            Label("Selecteren", image: .iconCheckCircle)
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
                    Label(allPinned ? "Losmaken" : "Vastzetten", systemImage: allPinned ? "pin.slash.fill" : "pin.fill")
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
        let titles = list.matching(search).conversations.sorted { $0.updatedAt > $1.updatedAt }
        let titleIDs = Set(titles.map(\.id))
        let inMessages = hits.filter { !titleIDs.contains($0.conversation.id) }
        if titles.isEmpty, inMessages.isEmpty {
            Text("Geen chats gevonden met “\(search.trimmingCharacters(in: .whitespaces))”.")
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .plainRow()
                .selectionDisabled()
        }
        if !titles.isEmpty {
            header("Chats")
                .selectionDisabled()
            ForEach(titles) { conversation in
                row(conversation)
            }
        }
        if !inMessages.isEmpty {
            header("In gesprekken")
                .selectionDisabled()
            ForEach(inMessages, id: \.hit.id) { found in
                AylaChatSearchRow(conversation: found.conversation, snippet: found.hit.snippet, search: search) {
                    actions.open(found.conversation)
                }
                .plainRow()
                .selectionDisabled()
            }
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
            PaveEmptyState(icon: .iconChat, title: "Nog geen chats", message: "Je gesprekken met Ayla komen hier te staan, ook die je op web of je Apple Watch begint.")
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .plainRow()
                .selectionDisabled()
        }
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
