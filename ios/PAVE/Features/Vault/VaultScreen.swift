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
                    Button {} label: {
                        Image(.iconPlus)
                    }
                    .accessibilityLabel("Document toevoegen")
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
        }
        .tint(.brandGreen)
    }

    private var folderStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(VaultCategory.folderCategories) { category in
                    VaultFolderTile(
                        category: category,
                        count: categoryCount(category),
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? .all : category
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
                    ForEach(VaultCategory.allCases) { category in
                        Button {
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
            if items.isEmpty {
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

    private func toggle(_ id: String, in set: inout Set<String>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        PaveHaptics.selection()
    }
}

private struct VaultFolderTile: View {
    let category: VaultCategory
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
                            .font(.system(size: 42, weight: .regular))
                            .overlay {
                                Image(systemName: category.folderIcon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                    .offset(y: 3)
                            }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.brandGreen)
                    .padding(.leading, 13)
                }
                .frame(height: 58)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
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
            .frame(width: 142)
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
