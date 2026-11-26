import PAVECore
import SwiftUI

/// One piece of evidence as a recipient sees it: what, where and when, whether it is verified, and whether there is a
/// file to open. A tap opens it.
struct ShareRecipientItemRow: View {
    let item: VaultItem
    let hasFile: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(item.category.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(18)
                    .foregroundStyle(Color.paveAccent)
                    .paveIconFrame(40)
                    .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                    if let detail = [item.organisationName, item.period].compactMap({ $0 }).filter({ !$0.isEmpty }).joined(separator: " · ").nilIfEmpty {
                        Text(detail)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    HStack(spacing: 8) {
                        VaultStatusBadge(item: item)
                            .padding(.leading, -4)
                        if hasFile {
                            Label(SharingMessages.recipientHasFile, image: .iconPaperclip)
                                .labelStyle(.titleAndIcon)
                                .textStyle(.caption)
                                .foregroundStyle(Color.paveAccent)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(.iconChevronRightSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
    }
}
