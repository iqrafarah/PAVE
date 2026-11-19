import PAVECore
import SwiftUI

/// "Zoeken in PAVE" from the menu (web AylaSearchDialog, made for a phone): a large field on top, tabs under it, and one
/// row per result with an icon, the words you typed in bold and when it was last changed. Before you type it shows your
/// recent chats, as ChatGPT does. Locked chats are never found.
struct PaveSearchScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultModel.self) private var vault: VaultModel?
    let list: AylaConversationList
    let searchMessages: (String) async -> [(hit: AylaSearchHit, conversation: AylaConversation)]
    let onOpenChat: (AylaConversation) -> Void
    let onOpenProject: (AylaProject) -> Void
    let onOpenItem: (VaultItem) -> Void

    @State private var query = ""
    @State private var tab = PaveSearchTab.all
    @State private var hits: [(hit: AylaSearchHit, conversation: AylaConversation)] = []
    @State private var previewURL: URL?
    @FocusState private var isFocused: Bool

    private var needle: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    PaveSearchField(text: $query, prompt: "Zoeken in PAVE", isFocused: $isFocused)
                    tabs
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        results
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Zoeken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(.iconXMark)
                            .paveToolbarHitArea()
                    }
                    .accessibilityLabel("Zoeken sluiten")
                }
            }
            .task { isFocused = true }
            .task(id: needle) {
                guard needle.count >= 2 else {
                    hits = []
                    return
                }
                // Waits until typing pauses, so not every letter asks the server.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                hits = await searchMessages(needle)
            }
            .vaultQuickLook($previewURL)
        }
        .tint(.paveAccent)
    }

    private var tabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(PaveSearchTab.available(vaultReady: vault?.state == .ready, projects: list.canUseProjects)) { option in
                    Button {
                        PaveHaptics.selection()
                        tab = option
                    } label: {
                        Text(option.rawValue)
                            .textStyle(.caption)
                            .foregroundStyle(tab == option ? Color.white : Color.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(tab == option ? Color.paveAccent : Color.white, in: .capsule)
                            .overlay { Capsule().strokeBorder(tab == option ? .clear : Color.cardBorder) }
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pave)
                    .accessibilityAddTraits(tab == option ? [.isSelected] : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var results: some View {
        if needle.isEmpty, tab == .all {
            let recent = Array(list.visible.sorted { $0.updatedAt > $1.updatedAt }.prefix(8))
            if recent.isEmpty {
                emptyText("Typ om te zoeken in je chats en je kluis.")
            } else {
                sectionTitle("Recente chats")
                ForEach(recent) { chat in
                    row(.chat, chat.title, list.project(of: chat)?.name, chat.updatedAt) { open(chat) }
                }
            }
        } else {
            // A tab without search words shows everything of its kind, as on the web.
            let chats = needle.isEmpty ? list.visible : list.matching(needle).conversations
            let titles = tab.shows(.chats) ? chats.sorted { $0.updatedAt > $1.updatedAt } : []
            let titleIDs = Set(titles.map(\.id))
            let inMessages = tab.shows(.chats) ? hits.filter { !titleIDs.contains($0.conversation.id) } : []
            let projects = tab.shows(.projects) ? PaveSearch.projects(list, matching: needle) : []
            let items = tab.shows(.items) ? PaveSearch.items(vault, matching: needle) : []
            let files = PaveSearch.files(vault, matching: needle, tab: tab)
            if titles.isEmpty, inMessages.isEmpty, projects.isEmpty, items.isEmpty, files.isEmpty {
                emptyText(needle.isEmpty ? "Hier staat nog niets." : "Geen resultaten voor “\(needle)”.")
            }
            ForEach(titles) { chat in
                row(.chat, chat.title, list.project(of: chat)?.name, chat.updatedAt) { open(chat) }
            }
            ForEach(inMessages, id: \.hit.id) { found in
                row(.chat, found.conversation.title, found.hit.snippet, found.conversation.updatedAt) { open(found.conversation) }
            }
            ForEach(projects) { project in
                row(.project, project.name, project.instructions, project.updatedAt) {
                    dismiss()
                    onOpenProject(project)
                }
            }
            ForEach(items) { item in
                row(.item, item.title, [item.organisationName, item.period].compactMap { $0 }.joined(separator: " · "), item.createdAt) {
                    dismiss()
                    onOpenItem(item)
                }
            }
            ForEach(files, id: \.file.id) { found in
                row(.file(.init(fileName: found.file.name)), found.file.name, found.item.title, found.item.createdAt) {
                    openFile(found.file)
                }
            }
        }
    }

    private func row(_ icon: AylaSearchResultRow.Icon, _ title: String, _ subtitle: String?, _ date: Date?, action: @escaping () -> Void) -> some View {
        AylaSearchResultRow(icon: icon, title: title, subtitle: subtitle, date: date, search: needle, onOpen: action)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.inkMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 32)
            .padding(.horizontal, 24)
    }

    private func open(_ chat: AylaConversation) {
        dismiss()
        onOpenChat(chat)
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
}
