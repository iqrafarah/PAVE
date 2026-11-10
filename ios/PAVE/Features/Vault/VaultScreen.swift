import SwiftUI

/// The mobile vault list. The view accepts real items when a vault service is added; until then the app shows an
/// honest empty state and the supplied design examples stay in previews only.
struct VaultScreen: View {
    let onShowMenu: (() -> Void)?
    var items: [VaultItem] = []
    private let usesPrototypeCounts: Bool

    @State private var selectedItems: Set<String>
    @State private var selectedCategories: Set<String> = []
    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool
    @State private var selectedCategory = VaultCategory.all
    @State private var selectedStatus = VaultStatusFilter.all
    @State private var showsSelection = false
    @State private var isGridView = true
    @State private var customFolders: [VaultCustomFolder] = []
    @State private var selectedCustomFolderID: UUID?
    @State private var showsNewFolder = false
    @State private var showsEvidenceNotice = false

    init(
        onShowMenu: (() -> Void)?,
        items: [VaultItem] = [],
        initiallySelectedItems: Set<String> = [],
        usesPrototypeCounts: Bool = false
    ) {
        self.onShowMenu = onShowMenu
        self.items = items
        self.usesPrototypeCounts = usesPrototypeCounts
        _selectedItems = State(initialValue: initiallySelectedItems)
    }

    private var visibleItems: [VaultItem] {
        let searched = items.filter { item in
            searchText.isEmpty || [item.title, item.organisation, item.period, item.category.title]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
        return searched.filter { item in
            guard selectedCustomFolderID == nil else { return false }
            let matchesCategory = selectedCategory == .all || item.category == selectedCategory
            let matchesStatus = selectedStatus.matches(item.status)
            return matchesCategory && matchesStatus
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    folderStrip
                    controls
                    if isSearching {
                        PaveSearchField(text: $searchText, prompt: "Zoek in je kluis", isFocused: $isSearchFocused)
                    }
                    if visibleItems.isEmpty {
                        emptyState
                    } else if isGridView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(visibleItems) { item in
                                VaultLibraryCard(item: item, isSelected: selectedItems.contains(item.id), isGrid: true) {
                                    toggle(item.id, in: &selectedItems)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(visibleItems) { item in
                                VaultLibraryCard(item: item, isSelected: selectedItems.contains(item.id), isGrid: false) {
                                    toggle(item.id, in: &selectedItems)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !selectedItems.isEmpty {
                    VaultSelectionBar(count: selectedItems.count) { showsSelection = true }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .background(.ultraThinMaterial)
                }
            }
            .mainScreenToolbar("Kluis", onShowMenu: onShowMenu)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isSearching {
                            isSearchFocused = false
                            searchText = ""
                            isSearching = false
                        } else {
                            isSearching = true
                            isSearchFocused = true
                        }
                    } label: {
                        Image(.iconSearch)
                    }
                    .accessibilityLabel(isSearching ? "Zoeken sluiten" : "Zoeken")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showsNewFolder = true
                        } label: {
                            Label("Map toevoegen", systemImage: "folder.badge.plus")
                        }
                        Button {
                            showsEvidenceNotice = true
                        } label: {
                            Label("Bewijs toevoegen", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(.iconPlus)
                    }
                    .accessibilityLabel("Toevoegen")
                }
            }
            .onChange(of: isSearching) { _, searching in
                isSearchFocused = searching
            }
            .sheet(isPresented: $showsSelection) {
                VaultAccessSelectionPanel(
                    items: items,
                    selectedCategories: $selectedCategories,
                    selectedItems: $selectedItems,
                    onContinue: { showsSelection = false }
                )
                .presentationDetents([.height(570), .large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showsNewFolder) {
                VaultAddFolderSheet(existingNames: customFolders.map(\.name)) { name in
                    let folder = VaultCustomFolder(name: name)
                    customFolders.append(folder)
                    selectedCustomFolderID = folder.id
                    selectedCategory = .all
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
            .alert("Bewijs toevoegen", isPresented: $showsEvidenceNotice) {
                Button("Begrepen", role: .cancel) {}
            } message: {
                Text("Bewijs toevoegen kan zodra de kluisopslag en uploadfunctie zijn aangesloten.")
            }
        }
        .tint(.brandGreen)
    }

    private var folderStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(VaultCategory.folderCategories) { category in
                    VaultFolderTile(
                        title: category.title,
                        icon: category.folderIcon,
                        count: categoryCount(category),
                        isSelected: selectedCategory == category
                    ) {
                        selectedCustomFolderID = nil
                        selectedCategory = selectedCategory == category ? .all : category
                        PaveHaptics.selection()
                    }
                }
                ForEach(customFolders) { folder in
                    VaultFolderTile(title: folder.name, icon: "folder", count: 0, isSelected: selectedCustomFolderID == folder.id) {
                        selectedCategory = .all
                        selectedCustomFolderID = folder.id
                        PaveHaptics.selection()
                    }
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.trailing, 1)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Menu {
                Section("Bewijs") {
                    ForEach(activeFilterCategories) { category in
                        Button {
                            selectedCustomFolderID = nil
                            selectedCategory = category
                        } label: {
                            if selectedCategory == category {
                                Label(category.filterTitle, systemImage: "checkmark")
                            } else {
                                Text(category.filterTitle)
                            }
                        }
                    }
                }
                Section("Status") {
                    ForEach(VaultStatusFilter.allCases) { status in
                        Button {
                            selectedStatus = status
                        } label: {
                            if selectedStatus == status {
                                Label(status.title, systemImage: "checkmark")
                            } else {
                                Text(status.title)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text("Filter")
                        .textStyle(.bodyMedium)
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 13)
                .frame(height: 40)
                .background(Color.surfaceTint, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.pave)
            .accessibilityLabel("Filter op bewijs en status")

            Spacer(minLength: 0)

            Button {
                withAnimation(.snappy(duration: 0.22)) { isGridView.toggle() }
                PaveHaptics.selection()
            } label: {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceTint, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.pave)
            .accessibilityLabel(isGridView ? "Lijstweergave" : "Rasterweergave")
        }
    }

    private var emptyState: some View {
        Group {
            if let selectedCustomFolderID,
               let folder = customFolders.first(where: { $0.id == selectedCustomFolderID }) {
                PaveEmptyState(
                    icon: .iconFolder,
                    title: "\(folder.name) is nog leeg",
                    message: "Voeg straks bewijs aan deze map toe."
                )
            } else if items.isEmpty {
                PaveEmptyState(
                    icon: .iconFolder,
                    title: "Je kluis is nog leeg",
                    message: "Hier bewaar je straks je diploma's, certificaten, projecten en ervaringen, zodat je alles op één plek hebt."
                )
            } else {
                PaveEmptyState(
                    icon: .iconSearch,
                    title: "Geen items gevonden",
                    message: "Pas je zoekopdracht of filters aan."
                )
            }
        }
        .padding(.horizontal, 20)
        .containerRelativeFrame(.vertical, count: 2, span: 1, spacing: 0)
    }

    private func categoryCount(_ category: VaultCategory) -> Int {
        if usesPrototypeCounts, category.prototypeCount > 0 { return category.prototypeCount }
        return items.count { $0.category == category }
    }

    private var activeFilterCategories: [VaultCategory] {
        [.all] + VaultCategory.allCases.filter { category in
            category != .all && (usesPrototypeCounts ? category.prototypeCount > 0 : items.contains { $0.category == category })
        }
    }

    private func toggle(_ id: String, in set: inout Set<String>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        PaveHaptics.selection()
    }
}

private struct VaultFolderTile: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Color.surfaceTint
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 32, weight: .regular))
                            .overlay {
                                Image(systemName: icon)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .offset(y: 3)
                            }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.brandGreen)
                    .padding(.leading, 13)
                }
                .frame(height: 54)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Text("\(count) items")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }
            .frame(width: 140)
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.brandGreen : Color.cardBorder, lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct VaultCustomFolder: Identifiable {
    let id = UUID()
    let name: String
}

private struct VaultAddFolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let existingNames: [String]
    let onCreate: (String) -> Void

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var alreadyExists: Bool {
        existingNames.contains { $0.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Nieuwe map")
                .textStyle(.calloutTitle)
                .foregroundStyle(Color.ink)

            TextField("Naam van de map", text: $name)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.white, in: .rect(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.cardBorder) }
                .submitLabel(.done)
                .onSubmit(create)

            if alreadyExists {
                Text("Je hebt al een map met deze naam.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.critical)
            }

            HStack(spacing: 12) {
                Button("Annuleren", role: .cancel) { dismiss() }
                    .buttonStyle(.pave)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.surfaceTint, in: .capsule)
                PavePrimaryButton(title: "Map aanmaken", action: create)
                    .disabled(trimmedName.isEmpty || alreadyExists)
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.canvas.ignoresSafeArea())
    }

    private func create() {
        guard !trimmedName.isEmpty, !alreadyExists else { return }
        onCreate(trimmedName)
        dismiss()
    }
}

private enum VaultStatusFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case verified
    case toVerify
    case rejected

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "Alle"
        case .verified: "Geverifieerd"
        case .toVerify: "Verifiëren"
        case .rejected: "Afgewezen"
        }
    }

    func matches(_ status: VaultItemStatus) -> Bool {
        switch self {
        case .all: true
        case .verified: status == .verified
        case .toVerify: status == .toVerify
        case .rejected: status == .rejected
        }
    }
}

#Preview("Kluis · items") {
    VaultScreen(
        onShowMenu: {}, items: VaultItem.mobilePrototype,
        initiallySelectedItems: ["full-stack-engineer", "leidinggevende"], usesPrototypeCounts: true
    )
}

#Preview("Kluis · leeg") {
    VaultScreen(onShowMenu: {})
}
