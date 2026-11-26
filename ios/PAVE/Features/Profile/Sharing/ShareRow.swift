import PAVECore
import SwiftUI

/// One share in a list: who it is for, what it is, how long it still runs, and whether it was looked at.
struct ShareRow: View {
    let share: ProfileShare

    private var isLive: Bool { share.isLive() }

    /// The organisation and what was shared, without repeating the recipient's name.
    private var subtitle: String {
        let organisation = share.recipientOrganisation.flatMap { $0.isEmpty || $0 == share.recipientName ? nil : $0 }
        return [organisation, share.title].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            ShareTemplateIcon(template: share.template, isMuted: !isLive)
            VStack(alignment: .leading, spacing: 2) {
                Text(share.recipientName)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(isLive ? Color.ink : Color.inkMuted)
                    .lineLimit(2)
                Text(subtitle)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(2)
                Text(SharingMessages.remaining(share))
                    .textStyle(.caption)
                    .foregroundStyle(share.state() == .paused ? Color.warning : Color.inkMuted)
                if isLive {
                    Text(SharingMessages.looksLine(share))
                        .textStyle(.caption)
                        .foregroundStyle(share.looks.isEmpty ? Color.inkMuted : Color.paveAccent)
                        .lineLimit(1)
                }
            }
            Image(.iconChevronRightSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
                .foregroundStyle(Color.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
