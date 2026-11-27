import PAVECore
import SwiftUI

/// One search for every organisation in the directory, one row per location ("Albert Heijn · Breda"), filtered on kind:
/// Alles, Onderwijs, Bedrijven, Overheid, Overig. Searched on organisation name, city, location name and address, on the
/// server, a page at a time; only locations where someone may confirm this kind of evidence. Two McDonald's in Tilburg
/// are two rows: "Westermarkt, Tilburg" and "Reeshof, Tilburg".
struct VaultOrganizationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultModel.self) private var vault
    let category: VaultCategory
    /// The chosen location.
    let selectedID: String?
    /// The organisation of the evidence, so its locations are listed straight away.
    var initialQuery = ""
    let onChoose: (VaultValidationPlace) -> Void

    private struct Query: Hashable {
        var text: String
        var kind: VaultOrganizationKind?
    }

    @State private var text = ""
    @State private var kind: VaultOrganizationKind?
    @State private var results: [VaultValidationPlace] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var failed = false

    private var query: Query { .init(text: text, kind: kind) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(results) { place in
                        row(place)
                            .onAppear { if place.id == results.last?.id { Task { await loadMore() } } }
                    }
                    if isLoadingMore { ProgressView().frame(maxWidth: .infinity) }
                } header: {
                    kindFilter.textCase(nil).padding(.bottom, 4)
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if isLoading && results.isEmpty {
                    ProgressView()
                } else if failed {
                    PaveEmptyState(icon: .iconSignalSlash, title: "Laden lukte niet", message: "Probeer het opnieuw.")
                        .listRowBackground(Color.clear)
                } else if results.isEmpty && !isLoading {
                    PaveEmptyState(icon: .iconBuildingOfficeSolid, title: "Geen organisatie gevonden", message: "Probeer een andere naam, plaats of categorie.")
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Organisatie kiezen")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Organisatie, plaats of adres")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(ApplyMessages.done) { dismiss() } } }
            .task(id: query) { await search() }
            .onAppear { if text.isEmpty { text = initialQuery } }
        }
        .presentationDetents([.large])
    }

    private var kindFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Alles", isSelected: kind == nil) { kind = nil }
                ForEach(VaultOrganizationKind.allCases) { option in
                    chip(option.filterTitle, isSelected: kind == option) { kind = option }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).textStyle(.caption)
                .foregroundStyle(isSelected ? Color.white : Color.ink)
                .padding(.horizontal, 14).frame(height: 32)
                .background(isSelected ? Color.paveAccentFill : Color.panel, in: .capsule)
                .overlay { Capsule().strokeBorder(isSelected ? Color.clear : Color.cardBorder) }
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The organisation, and under it the location ("Westermarkt, Tilburg") with its address; the kind too under "Alles".
    private func row(_ place: VaultValidationPlace) -> some View {
        Button {
            onChoose(place)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VaultPlaceLogo(place: place, size: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.organizationName).foregroundStyle(Color.ink)
                    Text((kind == nil ? "\(place.organizationKind.title) · " : "") + place.locationTitle)
                        .textStyle(.caption).foregroundStyle(Color.inkMuted)
                    if let address = place.addressLine {
                        Text(address).textStyle(.caption).foregroundStyle(Color.inkMuted).lineLimit(1)
                    }
                }
                Spacer()
                if place.id == selectedID { Image(.iconCheck).renderingMode(.template).resizable().scaledToFit().paveIconFrame(14).foregroundStyle(Color.paveAccent) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel([place.title, place.addressLine].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(place.id == selectedID ? [.isSelected] : [])
    }

    private func search() async {
        let current = query
        if !current.text.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
        guard !Task.isCancelled else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let page = try await vault.searchValidationPlaces(
                category: category, query: current.text, kind: current.kind, offset: 0
            )
            guard !Task.isCancelled, current == query else { return }
            results = page.rows
            total = page.total
            failed = false
        } catch {
            guard !Task.isCancelled else { return }
            failed = true
        }
    }

    private func loadMore() async {
        let current = query
        guard results.count < total, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true; defer { isLoadingMore = false }
        guard let page = try? await vault.searchValidationPlaces(
            category: category, query: current.text, kind: current.kind, offset: results.count
        ), current == query else { return }
        results += page.rows.filter { row in !results.contains { $0.id == row.id } }
        total = page.total
    }
}
