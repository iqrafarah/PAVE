import PAVECore
import SwiftUI

/// What the recipient sees on the web page, drawn here from the same data, so you know before and after sharing: your
/// photo and name on top, then the CV and letter, then the evidence per kind. Every piece opens, with its files when they
/// go along.
struct ShareRecipientPreview: View {
    let share: ProfileShare
    let items: [VaultItem]

    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileModel.self) private var profile: ProfileModel?
    @State private var opened: VaultItem?

    /// Only what the share names, in its order.
    private var shared: [VaultItem] {
        share.itemIDs.compactMap { id in items.first { $0.id == id && $0.status != .rejected && $0.archivedAt == nil } }
    }

    private var groups: [(category: VaultCategory, items: [VaultItem])] {
        VaultCategory.allCases.compactMap { category in
            let inIt = shared.filter { $0.category == category }
            return inIt.isEmpty ? nil : (category, inIt)
        }
    }

    private var files: Set<String> { Set(share.content.files ?? []) }
    private var hidden: Set<String> { Set(share.content.hiddenFiles ?? []) }
    private var brief: Set<String> { Set(share.content.brief ?? []) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PaveNotice(message: SharingMessages.previewLabel)
                    ShareRecipientHero(
                        share: share, photo: profile?.avatar, itemCount: shared.count,
                        verifiedCount: shared.filter { $0.status == .verified }.count
                    )
                    if share.content.cv != nil || share.content.letter != nil {
                        SharePanel(title: SharingMessages.application) {
                            if share.content.cv != nil { documentRow(ApplyMessages.cv) }
                            if share.content.cv != nil, share.content.letter != nil { ShareRowDivider(inset: 60) }
                            if share.content.letter != nil { documentRow(ApplyMessages.letter) }
                        }
                    }
                    ForEach(groups, id: \.category) { group in
                        SharePanel(title: group.category.title) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                if index > 0 { ShareRowDivider(inset: 66) }
                                ShareRecipientItemRow(item: item, hasFile: files.contains(item.id) && ShareFiles.sharesDocument(item, hidden: hidden)) {
                                    opened = item
                                }
                            }
                        }
                    }
                    Text(SharingMessages.recipientFooter)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas)
            .navigationTitle(SharingMessages.preview)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(ApplyMessages.done) { dismiss() } } }
            .sheet(item: $opened) { item in
                ShareRecipientItemDetail(item: item, isBrief: brief.contains(item.id), showsFiles: files.contains(item.id), hiddenFiles: hidden)
            }
        }
    }

    private func documentRow(_ title: String) -> some View {
        HStack(spacing: 12) {
            Image(.iconDocumentTextSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(18)
                .foregroundStyle(Color.paveAccent)
                .paveIconFrame(40)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            Text(title).textStyle(.listTitle).foregroundStyle(Color.ink)
            Spacer(minLength: 0)
            Text(SharingMessages.recipientPdf).textStyle(.caption).foregroundStyle(Color.inkMuted)
        }
        .padding(14)
    }
}
