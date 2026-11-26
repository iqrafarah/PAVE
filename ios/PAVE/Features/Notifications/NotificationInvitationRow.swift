import PAVECore
import SwiftUI

/// The demo invitation from a company in Meldingen, in the same shape as the other rows.
struct NotificationInvitationRow: View {
    let draft: ApplicationDraft
    let invitation: ApplicationInvitation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(.iconCalendarDaysSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.paveAccent)
                .frame(width: 18, height: 18)
                .frame(width: 36, height: 36)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(ApplyMessages.invitationTitle)
                    .textStyle(invitation.isRead ? .bodyMedium : .listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                Text(draft.vacancy.company)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(NotificationInboxRow.when(invitation.arrivesAt))
                    .textStyle(.caption)
                    .foregroundStyle(invitation.isRead ? Color.inkMuted : Color.paveAccent)
                if !invitation.isRead {
                    Circle().fill(Color.paveAccent).frame(width: 8, height: 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
