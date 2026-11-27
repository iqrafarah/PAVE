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
    /// Back to all chats; nil where the list is beside the page already.
    var onBack: (() -> Void)?

    @Environment(VaultModel.self) private var vault: VaultModel?
    @State private var tab = Tab.chats
    @State private var sort = SourceSort.newest
    @State private var kind: VaultCategory?
    @State private var editsProject = false
    @State private var picksSources = false
    @State private var fileSource: VaultFileSource?
    @State private var uploadFlow: VaultAddEvidenceModel?
    @State private var uploading: VaultAddEvidenceModel?
    @State private var openedItem: VaultItem?
    @State private var renaming: AylaConversation?
    @State private var newTitle = ""
    @State private var deleting: AylaConversation?

    private var chats: [AylaConversation] {
        model.conversationList.visible.filter { $0.projectID == project.id }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Nil while the sources or the vault are still loading.
    private var sourceItems: [VaultItem]? {
        guard let ids = model.projectSources[project.id], let vault, vault.state == .ready else { return nil }
        return ids.compactMap { id in vault.items.first { $0.id == id } }
    }

    private func shown(_ items: [VaultItem]) -> [VaultItem] {
        let filtered = items.filter { kind == nil || $0.category == kind }
        switch sort {
        case .newest: return filtered
        case .oldest: return filtered.reversed()
        case .name: return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if !project.instructions.isEmpty {
                Text(project.instructions)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ProjectPlansList(project: project)
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
        .padding(.bottom, 16)
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity)
        .task(id: project.id) {
            async let sources: Void = model.loadSources(of: project)
            if let vault, vault.state != .ready { await vault.load() }
            await sources
        }
        .onChange(of: sourceItems?.map(\.category)) { _, categories in
            // The kind that was filtered on is gone: show everything again.
            if let kind, let categories, !categories.contains(kind) { self.kind = nil }
        }
        .alert("Naam wijzigen", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Naam", text: $newTitle)
            Button(ApplyMessages.cancel, role: .cancel) { renaming = nil }
            Button("Bewaren") {
                if let renaming, !newTitle.trimmingCharacters(in: .whitespaces).isEmpty { model.rename(renaming, to: newTitle) }
                renaming = nil
            }
        }
        .confirmationDialog(AylaMessages.projectDeleteChatQuestion, isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible, presenting: deleting) { chat in
            Button("Verwijderen", role: .destructive) {
                PaveHaptics.tap(.heavy)
                model.delete([chat])
            }
        } message: { _ in
            Text(AylaMessages.projectDeleteChatHint)
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
        .vaultFilePicker(source: $fileSource, role: .document) { result in
            guard let vault else { return }
            // An uploaded file becomes evidence in the vault, filled in by Ayla, and a source of this project.
            let flow = VaultAddEvidenceModel(vault: vault, category: .projects, folderID: nil)
            flow.pick(result)
            if case .success = result { flow.fillWithAyla() }
            uploadFlow = flow
            uploading = flow
        }
        .sheet(item: $uploadFlow, onDismiss: addUploadedSource) { flow in
            VaultAddEvidenceSheet(flow: flow)
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
            if let onBack {
                PaveBackButton(label: AylaMessages.projectBackToChats, action: onBack)
                    .padding(.leading, -12)
            }
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
                        // The same as in the list of chats: hold a chat to rename, pin, take out or delete it.
                        .contextMenu { chatMenu(chat) }
                        .accessibilityActions { chatMenu(chat) }
                }
            }
            .padding(.horizontal, -8)
        }
    }

    @ViewBuilder
    private var sources: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let problem = model.sourcesProblem {
                PaveInlineError(message: problem)
            }
            if let items = sourceItems {
                if items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AylaMessages.sourcesEmptyTitle)
                            .textStyle(.listTitle)
                            .foregroundStyle(Color.ink)
                        Text(AylaMessages.sourcesEmpty)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    addMenu
                } else {
                    // Sort and filter where there is room next to the button; under it where there is not.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            sortMenu
                            kindMenu(items)
                            Spacer(minLength: 8)
                            addMenu
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            addMenu
                            HStack(spacing: 8) {
                                sortMenu
                                kindMenu(items)
                            }
                        }
                    }
                    let visible = shown(items)
                    if visible.isEmpty {
                        emptyText(AylaMessages.sourcesNoMatch)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(visible) { item in
                                sourceRow(item)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(AylaMessages.sourcesLoading)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.vertical, 12)
            }
        }
    }

    private var sortTitle: String {
        switch sort {
        case .newest: AylaMessages.sourcesSortNewest
        case .oldest: AylaMessages.sourcesSortOldest
        case .name: AylaMessages.sourcesSortName
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker(AylaMessages.sourcesSortLabel, selection: $sort) {
                Text(AylaMessages.sourcesSortNewest).tag(SourceSort.newest)
                Text(AylaMessages.sourcesSortOldest).tag(SourceSort.oldest)
                Text(AylaMessages.sourcesSortName).tag(SourceSort.name)
            }
        } label: {
            menuLabel(sortTitle)
        }
        .accessibilityLabel(AylaMessages.sourcesSortLabel)
        .accessibilityValue(sortTitle)
    }

    private func kindMenu(_ items: [VaultItem]) -> some View {
        let kinds = VaultCategory.allCases.filter { category in items.contains { $0.category == category } }
        let title = kind?.title ?? AylaMessages.sourcesAllKinds
        return Menu {
            Picker(AylaMessages.sourcesFilterLabel, selection: $kind) {
                Text(AylaMessages.sourcesAllKinds).tag(VaultCategory?.none)
                ForEach(kinds) { category in
                    Text(category.title).tag(VaultCategory?.some(category))
                }
            }
        } label: {
            menuLabel(title)
        }
        .accessibilityLabel(AylaMessages.sourcesFilterLabel)
        .accessibilityValue(title)
    }

    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
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
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(Color.panel, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.cardBorder) }
        .frame(minHeight: 44)
        .contentShape(.rect)
    }

    /// "Bronnen toevoegen": a file, which becomes evidence in the vault, or items already in the vault.
    private var addMenu: some View {
        Menu {
            Button {
                picksSources = true
            } label: {
                Label { Text(AylaMessages.sourcesFromVault) } icon: { Image(.iconFolderSolid) }
            }
            Button {
                fileSource = .files
            } label: {
                Label { Text(AylaMessages.sourcesUpload) } icon: { Image(.iconCloudArrowUpSolid) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(.iconPlus)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(12)
                    .accessibilityHidden(true)
                Text(AylaMessages.sourcesAdd)
                    .lineLimit(1)
            }
            .textStyle(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Color.paveAccentFill, in: .capsule)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
    }

    private func sourceRow(_ item: VaultItem) -> some View {
        HStack(spacing: 4) {
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
                        Text([item.category.singularTitle, item.createdAt.formatted(.dateTime.day().month(.abbreviated).locale(PaveLanguageStore.current.locale))].joined(separator: " · "))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityHint("Opent het bewijsstuk")

            Button {
                model.removeSource(item.id, from: project)
            } label: {
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(12)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("\(AylaMessages.sourcesRemove): \(item.title)")
        }
        .padding(.leading, 10)
        .padding(.vertical, 6)
        .background(Color.panel, in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    private func chatMenu(_ chat: AylaConversation) -> some View {
        Button {
            newTitle = chat.title
            renaming = chat
        } label: {
            Label("Naam wijzigen", tinted: .iconPencilSolid)
        }
        if model.conversationList.canPin {
            Button { model.togglePin(chat) } label: {
                Label { Text(chat.isPinned ? "Losmaken" : "Vastzetten") } icon: { Image(chat.isPinned ? .iconBookmarkSlashSolid : .iconBookmarkSolid).renderingMode(.template) }
            }
        }
        Button { model.move(chat, to: nil) } label: { Label(AylaMessages.removeFromProject, tinted: .iconMinusCircleSolid) }
        if model.conversationList.canArchive {
            Button { model.setArchived(true, [chat]) } label: { Label(RetentionMessages.archive, tinted: .iconArchiveBoxSolid) }
        }
        Divider()
        Button(role: .destructive) { deleting = chat } label: { Label("Verwijderen", tinted: .iconTrashSolid) }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The sheet's own item is already nil when it closes, so the flow is kept apart to read what it saved.
    private func addUploadedSource() {
        guard let id = uploading?.savedItemID else { return }
        uploading = nil
        Task { await model.addSources([id], to: project) }
    }
}

/// "Uit kluis halen": pick items from the vault, several at once. Items that are already a source are ticked. Items Ayla
/// may not use yet are asked about first, as on the web: otherwise she would not see them.
struct AylaSourcePicker: View {
    let chosen: Set<String>
    let onAdd: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(VaultModel.self) private var vault: VaultModel?
    @State private var picked: Set<String> = []
    @State private var query = ""
    @State private var asksPermission: [VaultItem]?
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
                    if vault?.state != .ready {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else if vault?.items.isEmpty ?? true {
                        note(AylaMessages.sourcesPickEmpty)
                    } else if items.isEmpty {
                        note(AylaMessages.sourcesPickNoMatch)
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
                    Button(ApplyMessages.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(picked.isEmpty ? "Toevoegen" : "Toevoegen (\(picked.count))", action: add)
                        .disabled(picked.isEmpty)
                }
            }
            .task { if let vault, vault.state != .ready { await vault.load() } }
            .confirmationDialog(
                AylaMessages.askNotAllowedTitle(asksPermission?.count ?? 1),
                isPresented: Binding(get: { asksPermission != nil }, set: { if !$0 { asksPermission = nil } }),
                titleVisibility: .visible,
                presenting: asksPermission
            ) { notAllowed in
                Button(AylaMessages.askAllowAll) {
                    Task {
                        for item in notAllowed { try? await vault?.setAylaAllowed(true, itemID: item.id) }
                        await vault?.load()
                        finish(Array(picked))
                    }
                }
                Button(AylaMessages.askWithoutThem) {
                    finish(Array(picked.subtracting(notAllowed.map(\.id))))
                }
                Button(ApplyMessages.cancel, role: .cancel) {}
            } message: { _ in
                Text(AylaMessages.askNotAllowedMessage)
            }
        }
        .tint(.paveAccent)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.inkMuted)
            .padding(.top, 24)
    }

    private func add() {
        let notAllowed = (vault?.items ?? []).filter { picked.contains($0.id) && $0.aylaAllowedAt == nil }
        if notAllowed.isEmpty { finish(Array(picked)) } else { asksPermission = notAllowed }
    }

    private func finish(_ ids: [String]) {
        if !ids.isEmpty { onAdd(ids) }
        dismiss()
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
                    Text(item.category.singularTitle)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 8)
                PaveCheckbox(isOn: isOn, size: 20)
                    .opacity(isSource ? 0.5 : 1)
                    .accessibilityHidden(true)
            }
            .padding(10)
            .background(Color.panel, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(isSource ? "Staat al in dit project" : "")
    }
}
