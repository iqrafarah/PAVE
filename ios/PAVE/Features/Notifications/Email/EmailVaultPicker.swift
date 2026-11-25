import PAVECore
import SwiftUI

/// "Uit kluis halen": evidence from your vault as attachments. Choosing an item adds its documents.
struct EmailVaultPicker: View {
    let onPick: ([EmailOutgoingAttachment]) -> Void

    @Environment(VaultModel.self) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var isAdding = false
    @State private var errorMessage: String?

    private var items: [VaultItem] { vault.items.filter { !vault.documents(of: $0).isEmpty } }

    var body: some View {
        NavigationStack {
            Group {
                if vault.state == .loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    PaveEmptyState(icon: .iconFolderSolid, title: "Geen bestanden in je kluis", message: "Voeg eerst bewijs met een document toe aan je kluis.")
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if let errorMessage {
                            PaveInlineError(message: errorMessage).listRowBackground(Color.clear)
                        }
                        ForEach(items) { item in row(item) }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(AylaMessages.sourcesFromVault)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }.disabled(isAdding)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isAdding ? "Bezig…" : selected.isEmpty ? "Voeg toe" : "Voeg toe (\(selected.count))") {
                        Task { await add() }
                    }
                    .disabled(selected.isEmpty || isAdding)
                }
            }
            .task { if vault.state != .ready { await vault.load() } }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.canvas)
    }

    private func row(_ item: VaultItem) -> some View {
        let isSelected = selected.contains(item.id)
        let count = vault.documents(of: item).count
        return Button {
            if isSelected { selected.remove(item.id) } else { selected.insert(item.id) }
        } label: {
            HStack(spacing: 12) {
                Image(item.category.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.ink)
                    .frame(width: 36, height: 36)
                    .background(item.category.tint, in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).textStyle(.bodyMedium).foregroundStyle(Color.ink).lineLimit(1)
                    Text("\(item.category.title) · \(count) \(count == 1 ? "bestand" : "bestanden")")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 8)
                Image(isSelected ? .iconCheckCircle : .iconCheckCircleOutline)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(isSelected ? Color.paveAccent : Color.inkMuted)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.panel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func add() async {
        isAdding = true
        errorMessage = nil
        var attachments: [EmailOutgoingAttachment] = []
        for item in items where selected.contains(item.id) {
            for file in vault.documents(of: item) {
                guard let data = await vault.data(of: file) else {
                    errorMessage = "\(file.name) kon niet uit je kluis worden gehaald. Probeer het opnieuw."
                    isAdding = false
                    return
                }
                attachments.append(EmailOutgoingAttachment(name: file.name, mimeType: file.mimeType, data: data))
            }
        }
        onPick(attachments)
        isAdding = false
        dismiss()
    }
}
