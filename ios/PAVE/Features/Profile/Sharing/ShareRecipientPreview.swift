import PAVECore
import SwiftUI

/// What the recipient sees on the web page, drawn here from the same data, so you know before and after sharing.
struct ShareRecipientPreview: View {
    let share: ProfileShare
    let items: [VaultItem]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PaveNotice(message: SharingMessages.previewLabel)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(share.content.profile.name).textStyle(.emptyTitle).foregroundStyle(Color.ink)
                        if let headline = share.content.profile.headline { Text(headline).textStyle(.bodyMedium).foregroundStyle(Color.paveAccent) }
                        if let email = share.content.profile.email { Text(email).textStyle(.caption).foregroundStyle(Color.inkMuted) }
                        Text("Gedeeld met \(share.recipient), \(SharingMessages.remaining(share).lowercased()). \(share.allowsDownload ? "Mag downloaden." : "Alleen bekijken.")")
                            .textStyle(.caption).foregroundStyle(Color.inkMuted).padding(.top, 4)
                    }
                    if let summary = share.content.profile.summary {
                        Text(summary).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                    }
                    if share.content.cv != nil || share.content.letter != nil {
                        SharePanel(title: SharingMessages.application) {
                            ForEach([share.content.cv != nil ? ApplyMessages.cv : nil, share.content.letter != nil ? ApplyMessages.letter : nil].compactMap { $0 }, id: \.self) { title in
                                Text("\(title) (pdf)").textStyle(.bodyMedium).foregroundStyle(Color.ink).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    if !items.isEmpty {
                        SharePanel(title: SharingMessages.fromVault) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                                    if let detail = [item.organisationName, item.period].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                                        Text(detail).textStyle(.caption).foregroundStyle(Color.inkMuted)
                                    }
                                    VaultStatusBadge(item: item).padding(.leading, -4)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if index < items.count - 1 { Divider().padding(.leading, 14) }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.canvas)
            .navigationTitle(SharingMessages.preview)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(ApplyMessages.done) { dismiss() } } }
        }
    }
}
