import PAVECore
import SwiftUI

/// The log of a share: every look and download, newest first, with what the visitor said about themselves.
struct ShareLooksList: View {
    let looks: [ShareLook]

    var body: some View {
        SharePanel(title: SharingMessages.looksTitle) {
            if looks.isEmpty {
                Text(SharingMessages.noLooks)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(looks.prefix(50).enumerated()), id: \.element.id) { index, look in
                    HStack(spacing: 12) {
                        Image(look.action == .download ? .iconFolderArrowDownSolid : .iconCheckBadgeSolid)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.paveAccent)
                            .frame(width: 16, height: 16)
                            .frame(width: 32, height: 32)
                            .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 9))
                            .accessibilityHidden(true)
                        Text(SharingMessages.look(look))
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                        Spacer(minLength: 8)
                        Text(NotificationInboxRow.when(look.date))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    if index < min(looks.count, 50) - 1 { Divider().padding(.leading, 58) }
                }
            }
        }
        if looks.contains(where: { $0.viewerName != nil || $0.viewerOrganisation != nil }) {
            Text(SharingMessages.lookUnchecked).textStyle(.caption).foregroundStyle(Color.inkMuted)
        }
    }
}
