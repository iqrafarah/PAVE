import PAVECore
import SwiftUI

/// The start page of a project (web /project/<id>), where a new chat in it begins: its icon and name, then its chats and
/// its sources ("Bronnen", vault items Ayla uses in every chat of the project). The text field below the page starts a
/// chat in the project.
struct AylaProjectStart: View {
    enum Tab: Hashable { case chats, sources }
    enum SourceSort: Hashable { case newest, oldest, name }

    let project: AylaProject
    let model: AylaChatModel
    let onOpenChat: (AylaConversation) -> Void

    @Environment(VaultModel.self) private var vault: VaultModel?
    @State private var tab = Tab.chats
    @State private var sort = SourceSort.newest
    @State private var kind: VaultCategory?
    @State private var editsProject = false
    @State private var picksSources = false
    @State private var openedItem: VaultItem?

    private var chats: [AylaConversation] {
        model.conversationList.visible.filter { $0.projectID == project.id }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var sourceItems: [VaultItem] {
        let ids = model.projectSources[project.id] ?? []
        let items = ids.compactMap { id in vault?.items.first { $0.id == id } }
        return items
    }

    private var shownSources: [VaultItem] {
        let filtered = sourceItems.filter { kind == nil || $0.category == kind }
        switch sort {
        case .newest: return filtered
        case .oldest: return filtered.reversed()
        case .name: return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if !project.instructions.isEmpty {
                Text(project.instructions)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if model.canUseSources {
                Picker("Weergave", selection: $tab) {
                    Text(AylaMessages.projectTabChats).tag(Tab.chats)
                    Text(AylaMessages.projectSources).tag(Tab.sources)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
            switch tab {
            case .chats: chatList
            case .sources: sources
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity)
        .task(id: project.id) {
            if let vault, vault.state != .ready { await vault.load() }
            await model.loadSources(of: project)
        }
        .sheet(isPresented: $editsProject) {
            AylaProjectEditor(project: project, canStyle: model.conversationList.canStyleProjects) { name, instructions, icon, color in
                var changed = project
                changed.name = name
                changed.instructions = instructions
                changed.icon = icon
                changed.color = color
                return await model.updateProject(changed)
            } onDelete: {
                model.deleteProject(project)
            }
            .paveSheet()
        }
        .sheet(isPresented: $picksSources) {
            AylaSourcePicker(chosen: Set(model.projectSources[project.id] ?? [])) { ids in
                Task { await model.addSources(ids, to: project) }
            }
            .paveSheet()
        }
        .sheet(item: $openedItem) { item in
            if let vault {
                VaultItemDetailView(itemID: item.id)
                    .environment(vault)
                    .paveSheet()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AylaProjectBadge(project: project, size: 48)
            Text(project.name)
                .textStyle(.emptyTitle)
                .foregroundStyle(Color.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button {
                editsProject = true
            } label: {
                Image(.iconSettings)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(20)
                    .foregroundStyle(Color.paveAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.paveSurfaceTint, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .accessibilityLabel(AylaMessages.projectSettings)
        }
    }

    @ViewBuilder
    private var chatList: some View {
        if chats.isEmpty {
            emptyText(AylaMessages.projectEmpty)
        } else {
            VStack(spacing: 2) {
                ForEach(chats) { chat in
                    AylaChatRow(conversation: chat, isCurrent: false) { onOpenChat(chat) }
                }
            }
        }
    }

    @ViewBuilder
    private var sources: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sort and filter where there is room next to the button; under it where there is not.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    sortMenu
                    kindMenu
                    Spacer(minLength: 8)
                    addButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    addButton
                    HStack(spacing: 8) {
                        sortMenu
                        kindMenu
                    }
                }
            }
            Text(AylaMessages.sourcesHint)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            if sourceItems.isEmpty {
                emptyText(AylaMessages.sourcesEmpty)
            } else {
                VStack(spacing: 8) {
                    ForEach(shownSources) { item in
                        sourceRow(item)
                    }
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sorteren", selection: $sort) {
                Text(AylaMessages.sourcesSortNewest).tag(SourceSort.newest)
                Text(AylaMessages.sourcesSortOldest).tag(SourceSort.oldest)
                Text(AylaMessages.sourcesSortName).tag(SourceSort.name)
            }
        } label: {
            menuLabel(sortTitle)
        }
        .accessibilityLabel("Sorteren")
    }

    private var sortTitle: String {
        switch sort {
        case .newest: AylaMessages.sourcesSortNewest
        case .oldest: AylaMessages.sourcesSortOldest
        case .name: AylaMessages.sourcesSortName
        }
    }

    private var kindMenu: some View {
        let kinds = VaultCategory.allCases.filter { category in sourceItems.contains { $0.category == category } }
        return Menu {
            Picker("Soort", selection: $kind) {
                Text(AylaMessages.sourcesAllKinds).tag(VaultCategory?.none)
                ForEach(kinds) { category in
                    Text(category.title).tag(VaultCategory?.some(category))
                }
            }
        } label: {
            menuLabel(kind?.title ?? AylaMessages.sourcesAllKinds)
        }
        .accessibilityLabel("Soort")
    }

    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .accessibilityHidden(true)
        }
        .textStyle(.caption)
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(Color.white, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.cardBorder) }
        .frame(minHeight: 44)
        .contentShape(.rect)
    }

    private var addButton: some View {
        Button {
            picksSources = true
        } label: {
            Label {
                Text(AylaMessages.sourcesAdd)
            } icon: {
                Image(.iconPlus).renderingMode(.template)
            }
            .textStyle(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Color.paveAccent, in: .capsule)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
    }

    private func sourceRow(_ item: VaultItem) -> some View {
        Button {
            openedItem = item
        } label: {
            HStack(spacing: 12) {
                VaultLogoAvatar(look: nil, name: item.organisationName ?? item.title, fileName: item.firstDocumentName ?? "", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Text([item.category.title, item.organisationName].compactMap { $0 }.joined(separator: " · "))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.pave)
        .contextMenu {
            Button(role: .destructive) {
                model.removeSource(item.id, from: project)
            } label: {
                Label { Text(AylaMessages.sourcesRemove) } icon: { Image(.iconXMark) }
            }
        }
        .accessibilityAction(named: AylaMessages.sourcesRemove) { model.removeSource(item.id, from: project) }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// "Bronnen toevoegen": pick items from the vault, several at once. Items that are already a source are ticked.
struct AylaSourcePicker: View {
    let chosen: Set<String>
    let onAdd: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(VaultModel.self) private var vault: VaultModel?
    @State private var picked: Set<String> = []
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var items: [VaultItem] {
        let all = vault?.items ?? []
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return all }
        return all.filter {
            "\($0.title) \($0.organisationName ?? "")".range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    PaveSearchField(text: $query, prompt: "Zoek in je kluis", isFocused: $isSearchFocused)
                    if vault?.items.isEmpty ?? true {
                        Text(AylaMessages.sourcesPickEmpty)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.inkMuted)
                            .padding(.top, 24)
                    }
                    ForEach(items) { item in
                        row(item)
                    }
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(AylaMessages.sourcesPickTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(picked.isEmpty ? AylaMessages.sourcesAdd : "\(AylaMessages.sourcesAdd) (\(picked.count))") {
                        onAdd(Array(picked))
                        dismiss()
                    }
                    .disabled(picked.isEmpty)
                }
            }
            .task { if let vault, vault.state != .ready { await vault.load() } }
        }
        .tint(.paveAccent)
    }

    private func row(_ item: VaultItem) -> some View {
        let isSource = chosen.contains(item.id)
        let isOn = isSource || picked.contains(item.id)
        return Button {
            guard !isSource else { return }
            PaveHaptics.selection()
            if picked.contains(item.id) { picked.remove(item.id) } else { picked.insert(item.id) }
        } label: {
            HStack(spacing: 12) {
                VaultLogoAvatar(look: nil, name: item.organisationName ?? item.title, fileName: item.firstDocumentName ?? "", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Text(item.category.title)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? Color.paveAccent : Color.inkMuted)
                    .opacity(isSource ? 0.5 : 1)
                    .accessibilityHidden(true)
            }
            .padding(10)
            .background(Color.white, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(isSource ? "Staat al in dit project" : "")
    }
}
