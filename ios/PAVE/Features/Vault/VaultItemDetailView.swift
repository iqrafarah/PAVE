import PAVECore
import SwiftUI

/// Everything about one item: where it comes from, whether it is confirmed and what you can do with it.
struct VaultItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultModel.self) private var model
    let itemID: String
    @State private var isEditing = false
    @State private var confirmsDelete = false

    private var item: VaultItem? { model.items.first { $0.id == itemID } }

    var body: some View {
        NavigationStack {
            Group {
                if let item {
                    content(item)
                } else {
                    Color.canvas.onAppear { dismiss() }
                }
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Klaar") { dismiss() }
                }
                if let item {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            VaultItemActionButtons(item: item, onEdit: { isEditing = true }, onDelete: { confirmsDelete = true })
                        } label: {
                            Image(.iconEllipsis)
                                .renderingMode(.template)
                        }
                        .accessibilityLabel("Meer")
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                if let item { VaultItemEditor(item: item) }
            }
            .confirmationDialog("Uit je kluis verwijderen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Verwijderen", role: .destructive) {
                    guard let item else { return }
                    PaveHaptics.tap(.heavy)
                    Task { await model.delete(item) }
                }
            } message: {
                Text(VaultMessages.deleteItemMessage)
            }
        }
        .tint(.brandGreen)
    }

    private func content(_ item: VaultItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    CompanyMonogram(name: item.organisationName ?? item.title, size: 56)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.category.singularTitle)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                        Text(item.title)
                            .textStyle(.emptyTitle)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        VaultStatusBadge(status: item.status)
                    }
                }

                section("Status") {
                    Text(item.status.explanation)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                section("Gegevens") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let place = item.place {
                            PaveIconLabel(icon: .iconBuildingOfficeSolid, text: place)
                        }
                        if let period = item.period {
                            PaveIconLabel(icon: .iconCalendarDaysSolid, text: period)
                        }
                        if let folder = model.folder(item.folderID) {
                            PaveIconLabel(icon: .iconFolderSolid, text: "In de map \(folder.name)")
                        }
                        PaveIconLabel(icon: .iconInformationCircle, text: "\(item.source.title), \(VaultDay(item.createdAt).full)")
                    }
                }

                if let description = item.description, !description.isEmpty {
                    section("Omschrijving") {
                        Text(description)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }

                if !item.skills.isEmpty {
                    section("Vaardigheden") {
                        FlowLayout(spacing: 6) {
                            ForEach(item.skills, id: \.self) { VaultSkillChip(text: $0) }
                        }
                    }
                }

                if !item.files.isEmpty {
                    section("Bestanden") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(item.files) { file in
                                PaveIconLabel(icon: .iconDocumentSolid, text: file.name)
                            }
                        }
                    }
                }

                if item.isEditable {
                    PaveSecondaryButton(title: "Aanpassen", icon: .iconPencil) { isEditing = true }
                }
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white, in: .rect(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
        }
    }
}

#Preview {
    VaultItemDetailView(itemID: "teamleider")
        .environment(VaultModel(previewContents: .preview))
}
