import PAVECore
import SwiftUI

/// An employer at the fair invites you: when, their message, and your answer. Once you said yes: the calendar and
/// practising with Ayla.
struct FairInvitationRow: View {
    let application: FairApplication
    let onAnswer: (Bool) -> Void
    let onCalendar: () -> Void
    let onPractise: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ShareRowIcon(icon: .iconCalendarDaysSolid)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SharingMessages.dayInvitedFor(application.vacancyTitle)).textStyle(.listTitle).foregroundStyle(Color.ink)
                    if let moment = application.invitedFor {
                        Text(ApplyMessages.slot(moment)).textStyle(.bodyMedium).foregroundStyle(Color.paveAccent)
                    }
                }
            }
            if let message = application.invitationMessage, !message.isEmpty {
                Text("“\(message)”").textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
            }
            switch application.answer {
            case nil:
                HStack(spacing: 10) {
                    PaveSecondaryButton(title: SharingMessages.dayDecline) { onAnswer(false) }
                    PavePrimaryButton(title: SharingMessages.dayAccept) {
                        PaveHaptics.success()
                        onAnswer(true)
                    }
                }
            case .accepted:
                Text(SharingMessages.dayAccepted).textStyle(.chip).foregroundStyle(Color.paveAccent)
                HStack(spacing: 10) {
                    PaveSecondaryButton(title: ApplyMessages.talkToCalendar, icon: .iconCalendarDaysSolid, action: onCalendar)
                    PaveSecondaryButton(title: SharingMessages.dayPractise, icon: .iconChatBubbleLeftEllipsisSolid, action: onPractise)
                }
            case .declined:
                Text(SharingMessages.dayDeclined).textStyle(.chip).foregroundStyle(Color.inkMuted)
            }
        }
        .padding(14)
    }
}
