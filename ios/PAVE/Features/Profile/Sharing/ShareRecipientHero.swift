import PAVECore
import SwiftUI

/// The top of what a recipient sees: your photo and name, what you study, a few words of your own, and at a glance how
/// much of it is verified and what is in it.
struct ShareRecipientHero: View {
    let share: ProfileShare
    let photo: UIImage?
    let itemCount: Int
    let verifiedCount: Int

    private var profile: ShareProfile { share.content.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                AccountBadge(name: profile.name, image: share.content.profile.showsPhoto == true ? photo : nil, size: 76)
                    .overlay { Circle().strokeBorder(Color.paveSurfaceTint, lineWidth: 3) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name.isEmpty ? SharingMessages.you : profile.name)
                        .textStyle(.emptyTitle)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let headline = profile.headline {
                        Text(headline)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.paveAccent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let email = profile.email {
                        Text(email)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
            if let summary = profile.summary {
                Text(summary)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.canvas, in: .rect(cornerRadius: 14))
            }
            FlowLayout(spacing: 8) {
                if verifiedCount > 0 {
                    fact(.iconCheckBadgeSolid, SharingMessages.recipientVerified(verifiedCount), isStrong: true)
                }
                fact(.iconFolderSolid, SharingMessages.recipientItems(itemCount))
                if share.content.cv != nil { fact(.iconDocumentTextSolid, ApplyMessages.cv) }
                if share.content.letter != nil { fact(.iconDocumentTextSolid, ApplyMessages.letter) }
            }
            Text(SharingMessages.recipientFor(share))
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 20))
        .overlay(alignment: .top) {
            // A band of the PAVE colour along the top, so the page has a face of its own.
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(Color.paveAccentFill)
                .frame(height: 6)
        }
    }

    private func fact(_ icon: ImageResource, _ text: String, isStrong: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .accessibilityHidden(true)
            Text(text).textStyle(.caption)
        }
        .foregroundStyle(isStrong ? Color.white : Color.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isStrong ? Color.paveAccentFill : Color.paveSurfaceTint, in: .capsule)
    }
}
