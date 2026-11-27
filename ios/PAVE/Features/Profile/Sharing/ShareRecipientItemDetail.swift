import PAVECore
import SwiftUI

/// A piece of evidence opened by the recipient: everything that was shared of it, who verified it, and its files to
/// open, such as the grade list behind a diploma.
struct ShareRecipientItemDetail: View {
    let item: VaultItem
    /// Shared briefly: no description and no skills.
    let isBrief: Bool
    let showsFiles: Bool
    var hiddenFiles: Set<String> = []

    @Environment(VaultModel.self) private var vault
    @State private var previewURL: URL?

    private var documents: [VaultItem.File] { showsFiles ? ShareFiles.documents(of: item, hidden: hiddenFiles) : [] }

    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.category.title)
                            .textStyle(.caption)
                            .foregroundStyle(Color.paveAccent)
                        Text(item.title)
                            .textStyle(.emptyTitle)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail = [item.organisationName, item.period].compactMap({ $0 }).filter({ !$0.isEmpty }).joined(separator: " · ").nilIfEmpty {
                            Text(detail)
                                .textStyle(.bodyMedium)
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                    verification
                    if !isBrief, let description = item.description, !description.isEmpty {
                        Text(description)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !isBrief, !item.skills.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(item.skills, id: \.self) { skill in
                                Text(skill)
                                    .textStyle(.caption)
                                    .foregroundStyle(Color.ink)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.paveSurfaceTint, in: .capsule)
                            }
                        }
                    }
                    if documents.isEmpty {
                        Text(SharingMessages.recipientNoFile)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        SharePanel(title: SharingMessages.recipientFiles) {
                            ForEach(Array(documents.enumerated()), id: \.element.id) { index, file in
                                if index > 0 { ShareRowDivider(inset: 70) }
                                Button { open(file) } label: {
                                    HStack(spacing: 12) {
                                        VaultThumbnail(source: .file(file))
                                            .frame(width: 44, height: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.name)
                                                .textStyle(.bodyMedium)
                                                .foregroundStyle(Color.ink)
                                                .lineLimit(2)
                                            Text(VaultUpload.kind(of: file.mimeType))
                                                .textStyle(.caption)
                                                .foregroundStyle(Color.inkMuted)
                                        }
                                        Spacer(minLength: 0)
                                        Text(SharingMessages.recipientOpen)
                                            .textStyle(.chip)
                                            .foregroundStyle(Color.paveAccent)
                                    }
                                    .padding(12)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.pave)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .vaultFilePage($previewURL)
        }
    }

    @ViewBuilder
    private var verification: some View {
        if item.status == .verified {
            HStack(spacing: 10) {
                Image(.iconCheckBadgeSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.paveAccent)
                    .accessibilityHidden(true)
                Text(SharingMessages.recipientVerifiedBy(item.lastRequest?.status == .verified ? item.lastRequest?.organisationName : nil))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
        } else {
            VaultStatusBadge(item: item)
                .padding(.leading, -4)
        }
    }

    private func open(_ file: VaultItem.File) {
        Task {
            guard let data = await vault.data(of: file) else { return }
            previewURL = VaultPreviewFile.url(for: data, named: file.name)
        }
    }
}
