import PAVECore
import SwiftUI

/// Opens a chat with Ayla from elsewhere in PAVE, such as the archive in Instellingen.
extension EnvironmentValues {
    @Entry var openAylaChat: ((AylaConversation) -> Void)?
}

/// Instellingen › Archief (web /instellingen/gearchiveerd): the chats and the evidence you archived. They are out of
/// sight but kept; search and sort them, open one, put it back or delete it for good.
struct ArchiveScreen: View {
    private enum Kind: String, CaseIterable, Identifiable {
        case chats = "Chats"
        case evidence = "Bewijsstukken"

        var id: Self { self }
    }

    private enum Sort: Hashable { case newest, oldest, name }

    @Environment(AylaChatModel.self) private var chats: AylaChatModel?
    @Environment(VaultModel.self) private var vault: VaultModel?
    @Environment(\.openAylaChat) private var openChat
    @State private var kind = Kind.chats
    @State private var query = ""
    @State private var sort = Sort.newest
    @State private var chatToDelete: AylaConversation?
    @State private var itemToDelete: VaultItem?
    @State private var openedItem: VaultItem?
    @FocusState private var isSearchFocused: Bool

    private var needle: String { query.trimmingCharacters(in: .whitespaces) }

    private func matches(_ text: String) -> Bool {
        needle.isEmpty || text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private var archivedChats: [AylaConversation] {
        let found = (chats?.conversationList.archived ?? []).filter { matches($0.title) }
        switch sort {
        case .newest: return found.sorted { $0.updatedAt > $1.updatedAt }
        case .oldest: return found.sorted { $0.updatedAt < $1.updatedAt }
        case .name: return found.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    private var archivedItems: [VaultItem] {
        let found = (vault?.archived ?? []).filter { matches("\($0.title) \($0.organisationName ?? "")") }
        switch sort {
        case .newest: return found.sorted { ($0.archivedAt ?? $0.updatedAt) > ($1.archivedAt ?? $1.updatedAt) }
        case .oldest: return found.sorted { ($0.archivedAt ?? $0.updatedAt) < ($1.archivedAt ?? $1.updatedAt) }
        case .name: return found.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    private var isLoading: Bool {
        switch kind {
        case .chats: chats.map { $0.isAvailable && !$0.hasLoadedList } ?? false
        case .evidence: vault.map { $0.state == .loading } ?? false
        }
    }

    var body: some View {
        SettingsPage(title: RetentionMessages.archiveTitle) {
            Picker("Soort", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(RetentionMessages.archiveHint)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 8)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                PaveSearchField(text: $query, prompt: kind == .chats ? "Zoek in chats" : "Zoek in bewijsstukken", isFocused: $isSearchFocused)
                sortMenu
                    .fixedSize()
            }
            content
        }
        .task {
            await chats?.refreshConversations()
            if let vault, vault.state != .ready { await vault.load() }
        }
        .confirmationDialog("Chat verwijderen?", isPresented: isPresented($chatToDelete), titleVisibility: .visible, presenting: chatToDelete) { chat in
            Button("Verwijderen", role: .destructive) {
                PaveHaptics.tap(.heavy)
                chats?.delete([chat])
            }
        } message: { chat in
            Text(AylaMessages.deleteChatMessage(chat.title))
        }
        .confirmationDialog("Uit je kluis verwijderen?", isPresented: isPresented($itemToDelete), titleVisibility: .visible, presenting: itemToDelete) { item in
            Button("Verwijderen", role: .destructive) {
                PaveHaptics.tap(.heavy)
                Task { await vault?.delete(item) }
            }
        } message: { _ in
            Text(VaultMessages.deleteItemMessage)
        }
        .sheet(item: $openedItem) { item in
            if let vault {
                VaultItemDetailView(itemID: item.id)
                    .environment(vault)
                    .paveSheet()
            }
        }
        .alert("Dat lukte niet", isPresented: Binding(get: { chats?.chatsProblem != nil }, set: { if !$0 { chats?.chatsProblem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(chats?.chatsProblem ?? "")
        }
        .alert("Dat lukte niet", isPresented: Binding(get: { vault?.problem != nil && openedItem == nil }, set: { if !$0 { vault?.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vault?.problem ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            HStack(spacing: 10) {
                ProgressView()
                Text("Laden…")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            switch kind {
            case .chats:
                if chats?.conversationList.archived.isEmpty ?? true {
                    empty("Je hebt geen chats in je archief", "Houd een chat ingedrukt en kies Archiveren om hem hier te bewaren.")
                } else if archivedChats.isEmpty {
                    noMatch("Geen chats gevonden.")
                } else {
                    SettingsGroup {
                        ForEach(archivedChats) { chat in
                            row(title: chat.title, date: chat.updatedAt, icon: .iconChatBubbleLeftEllipsisSolid) {
                                openChat?(chat)
                            } onRestore: {
                                chats?.setArchived(false, [chat])
                            } onDelete: {
                                chatToDelete = chat
                            }
                        }
                    }
                }
            case .evidence:
                if vault?.archived.isEmpty ?? true {
                    empty("Je hebt geen bewijsstukken in je archief", "Houd een bewijsstuk in je kluis ingedrukt en kies Archiveren om het hier te bewaren.")
                } else if archivedItems.isEmpty {
                    noMatch("Geen bewijsstukken gevonden.")
                } else {
                    SettingsGroup {
                        ForEach(archivedItems) { item in
                            row(title: item.title, date: item.archivedAt ?? item.updatedAt, icon: .iconFolderSolid) {
                                openedItem = item
                            } onRestore: {
                                Task { await vault?.setArchived(false, item) }
                            } onDelete: {
                                itemToDelete = item
                            }
                        }
                    }
                }
            }
        }
    }

    private var sortTitle: String {
        switch sort {
        case .newest: "Nieuwste eerst"
        case .oldest: "Oudste eerst"
        case .name: "Naam"
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sorteren", selection: $sort) {
                Text("Nieuwste eerst").tag(Sort.newest)
                Text("Oudste eerst").tag(Sort.oldest)
                Text("Naam").tag(Sort.name)
            }
        } label: {
            HStack(spacing: 6) {
                Text(sortTitle)
                    .lineLimit(1)
                Image(.iconChevronDown)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconHeight(6)
                    .accessibilityHidden(true)
            }
            .textStyle(.caption)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Color.panel, in: .capsule)
            .contentShape(.capsule)
        }
        .accessibilityLabel("Sorteren")
        .accessibilityValue(sortTitle)
    }

    /// The row opens what it is; Terugzetten and Verwijderen are buttons of their own, as on the web. Where the row is
    /// narrow, they go under the title.
    private func row(title: String, date: Date, icon: ImageResource, onOpen: @escaping () -> Void, onRestore: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                rowLabel(title: title, date: date, icon: icon, onOpen: onOpen)
                rowButtons(title: title, onRestore: onRestore, onDelete: onDelete)
            }
            VStack(alignment: .leading, spacing: 8) {
                rowLabel(title: title, date: date, icon: icon, onOpen: onOpen)
                rowButtons(title: title, onRestore: onRestore, onDelete: onDelete)
                    .padding(.leading, 46)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func rowLabel(title: String, date: Date, icon: ImageResource, onOpen: @escaping () -> Void) -> some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(17)
                    .foregroundStyle(Color.white)
                    .paveIconFrame(32)
                    .background(Color.paveAccentFill, in: .rect(cornerRadius: 8))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Text(date.formatted(.dateTime.day().month(.abbreviated).year().locale(PaveLanguageStore.current.locale)))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
    }

    private func rowButtons(title: String, onRestore: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(RetentionMessages.restore, action: onRestore)
                .textStyle(.caption)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Color.paveSurfaceTint, in: .capsule)
                .frame(minHeight: 44)
                .contentShape(.rect)
                .buttonStyle(.pave)
                .accessibilityLabel("\(RetentionMessages.restore): \(title)")
            Button("Verwijderen", action: onDelete)
                .textStyle(.caption)
                .foregroundStyle(Color.critical)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Color.criticalSurface, in: .capsule)
                .frame(minHeight: 44)
                .contentShape(.rect)
                .buttonStyle(.pave)
                .accessibilityLabel("Verwijderen: \(title)")
        }
        .fixedSize()
    }

    private func empty(_ title: String, _ message: String) -> some View {
        PaveEmptyState(icon: .iconArchiveBoxSolid, title: title, message: message)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
    }

    private func noMatch(_ text: String) -> some View {
        Text(text)
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    private func isPresented<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
