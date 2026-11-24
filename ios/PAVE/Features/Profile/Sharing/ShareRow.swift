import PAVECore
import SwiftUI

/// One share in the list: who it is for, what, how long still, and how often it was looked at.
struct ShareRow: View {
    let share: ProfileShare

    private var isLive: Bool { share.isLive() }
    private var lastLook: Date? { share.looks.first?.date }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ShareTemplateIcon(template: share.template, isMuted: !isLive)
            VStack(alignment: .leading, spacing: 3) {
                Text(share.recipient)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(isLive ? Color.ink : Color.inkMuted)
                    .lineLimit(1)
                Text(share.title)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
                if isLive {
                    Text(SharingMessages.looks(share.looks.count))
                        .textStyle(.caption)
                        .foregroundStyle(share.looks.isEmpty ? Color.inkMuted : Color.paveAccent)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(SharingMessages.remaining(share))
                    .textStyle(.caption)
                    .foregroundStyle(share.state() == .paused ? Color.warning : Color.inkMuted)
                    .lineLimit(1)
                if let lastLook, isLive {
                    Text(NotificationInboxRow.when(lastLook))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
