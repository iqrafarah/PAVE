import PAVECore
import SwiftUI

/// One search for every organisation in the directory, filtered on kind: Alles, Onderwijs, Bedrijven, Overheid, Overig.
/// Searched on the server a page at a time; only organisations where someone may confirm this kind of evidence.
struct VaultOrganizationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultModel.self) private var vault
    let category: VaultCategory
    let selectedID: String?
    let onChoose: (VaultValidationOrganization) -> Void

    private struct Query: Hashable {
        var text: String
        var kind: VaultOrganizationKind?
    }

    @State private var text = ""
    @State private var kind: VaultOrganizationKind?
    @State private var results: [VaultValidationOrganization] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var failed = false

    private var query: Query { .init(text: text, kind: kind) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(results) { organization in
                        row(organization)
                            .onAppear { if organization.id == results.last?.id { Task { await loadMore() } } }
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
                    ContentUnavailableView("Laden lukte niet", systemImage: "wifi.exclamationmark", description: Text("Probeer het opnieuw."))
                } else if results.isEmpty && !isLoading {
                    ContentUnavailableView("Geen organisatie gevonden", systemImage: "building.2", description: Text("Probeer een andere naam of categorie."))
                }
            }
            .navigationTitle("Organisatie kiezen")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Naam van de organisatie")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Gereed") { dismiss() } } }
            .task(id: query) { await search() }
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

    /// The kind only under "Alles": with a kind chosen it would say the same on every row.
    private func row(_ organization: VaultValidationOrganization) -> some View {
        Button {
            onChoose(organization)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(organization.name).foregroundStyle(Color.ink)
                    let details = [kind == nil ? organization.kindTitle : nil, organization.citySummary].compactMap { $0 }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · ")).font(.caption).foregroundStyle(Color.inkMuted)
                    }
                }
                Spacer()
                if organization.id == selectedID { Image(systemName: "checkmark").foregroundStyle(Color.paveAccent) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(organization.id == selectedID ? [.isSelected] : [])
    }

    private func search() async {
        let current = query
        if !current.text.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
        guard !Task.isCancelled else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let page = try await vault.searchValidationOrganizations(
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
        guard let page = try? await vault.searchValidationOrganizations(
            category: category, query: current.text, kind: current.kind, offset: results.count
        ), current == query else { return }
        results += page.rows.filter { row in !results.contains { $0.id == row.id } }
        total = page.total
    }
}
