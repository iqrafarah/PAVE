import SwiftUI

/// One notification in the inbox or in "Recent verwijderd": icon, title, who it is from, time and a hint on the right.
struct NotificationRow: View {
    let notification: PaveNotification
    var isUnread = false
    /// Bottom right, in green: what a tap does ("Bekijk gesprek"), or in the bin how long it can still be restored.
    let hint: String
    var showsArrow = true

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(notification.kind.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.brandGreen)
                .frame(width: 20, height: 20)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.85), in: .rect(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .textStyle(.caption)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                HStack {
                    Text(notification.date.formatted(date: .omitted, time: .shortened))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                    Spacer(minLength: 6)
                    Text(hint)
                        .textStyle(.caption)
                        .foregroundStyle(Color.brandGreen)
                    if showsArrow {
                        Image(.iconArrowRight)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(Color.brandGreen)
                    }
                }
            }
            Spacer(minLength: 0)
            if isUnread {
                Circle().fill(Color.brandGreen).frame(width: 6, height: 6)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(isUnread ? Color.surfaceTint : Color.white, in: .rect(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(Color.cardBorder) }
        .contentShape(.rect(cornerRadius: 13))
        .contentShape(.contextMenuPreview, .rect(cornerRadius: 13))
    }

    /// A decision names the evidence and the organisation that decided, so you know which item it is about.
    private var subtitle: String {
        switch notification.kind {
        case .verifiedEvidence, .rejectedEvidence:
            [notification.documentName, notification.personName].compactMap { $0 }.joined(separator: " · ")
        case .conversation, .verificationRequest:
            notification.personName
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        NotificationRow(
            notification: .init(id: "1", kind: .verifiedEvidence, title: "Bewijs geverifieerd", personName: "Fontys Hogeschool", date: .now, documentName: "Hbo-ICT propedeuse"),
            isUnread: true,
            hint: "Bekijk bewijs"
        )
        NotificationRow(
            notification: .init(id: "2", kind: .conversation, title: "Gesprek voor stage", personName: "Ayla", date: .now),
            hint: "Nog 6 dagen",
            showsArrow: false
        )
    }
    .padding()
    .background(Color.canvas)
}
