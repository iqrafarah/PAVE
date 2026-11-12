import PAVECore
import SwiftUI

/// Everything about one item: where it comes from, whether it is confirmed and what you can do with it.
struct VaultItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultModel.self) private var model
    let itemID: String
    @State private var isEditing = false
    @State private var requestsConfirmation = false
    @State private var confirmsDelete = false
    @State private var look: VaultLogoLook?

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
            }
            .sheet(isPresented: $isEditing) {
                if let item { VaultEvidenceEditor(vault: model, item: item).paveSheet() }
            }
            .sheet(isPresented: $requestsConfirmation) {
                if let item {
                    VaultRequestConfirmationSheet(item: item, documentCount: model.documents(of: item).count).paveSheet()
                }
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
                    VaultLogoAvatar(look: look, name: item.organisationName ?? item.title, size: 56)
                        .task(id: model.logo(of: item)?.id) {
                            guard let logo = model.logo(of: item) else { look = nil; return }
                            let loaded = await model.look(of: logo)
                            withAnimation(.easeOut(duration: 0.25)) { look = loaded }
                        }
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // In the content rather than the navigation bar: on the outer display of the iPhone Duo the bar puts
                    // its buttons in the status column, where the sheet does not reach.
                    Menu {
                        VaultItemActionButtons(
                            item: item,
                            onEdit: { isEditing = true },
                            onRequestConfirmation: { requestsConfirmation = true },
                            onDelete: { confirmsDelete = true }
                        )
                    } label: {
                        Image(.iconEllipsis)
                            .renderingMode(.template)
                            .foregroundStyle(Color.ink)
                            .frame(width: 44, height: 44)
                            .background(Color.surfaceTint, in: .circle)
                            .contentShape(.circle)
                    }
                    .accessibilityLabel("Meer")
                }

                section("Status") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(item.status.explanation)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        // Also after a change: a confirmed item that was changed is Niet bevestigd again and can be sent anew.
                        if item.status != .verified {
                            PaveSecondaryButton(
                                title: item.status == .rejected ? VaultMessages.requestAgainAction : VaultMessages.requestAction,
                                icon: .iconCheckBadgeSolid
                            ) {
                                requestsConfirmation = true
                            }
                        }
                    }
                }

                section("Gegevens") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let place = item.place {
                            PaveIconLabel(icon: .iconBuildingOfficeSolid, text: place)
                        }
                        if let period = item.period {
                            PaveIconLabel(icon: .iconCalendarDaysSolid, text: period)
                        }
                        let folders = model.folders(of: item)
                        if !folders.isEmpty {
                            PaveIconLabel(icon: .iconFolderSolid, text: VaultMessages.inFolders(folders.map(\.name)))
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

                let documents = model.documents(of: item)
                if !documents.isEmpty {
                    section("Bestanden") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 12, alignment: .top)], alignment: .leading, spacing: 14) {
                            ForEach(documents) { VaultFileTile(file: $0) }
                        }
                    }
                }

                PaveSecondaryButton(title: "Aanpassen", icon: .iconPencil) { isEditing = true }
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
