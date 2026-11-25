import PAVECore
import SwiftUI

/// One applicant's card as the employer sees it, with the button to invite.
struct EmployerInboxCard: View {
    let application: InboxApplication
    let onInvite: () -> Void

    private var days: String {
        let short = application.availability.days.compactMap { Availability.Day(rawValue: $0) }.map(SharingMessages.day).joined(separator: ", ")
        let hours = application.availability.maxHours.map { SharingMessages.hours($0) }
        return [short.isEmpty ? nil : short, hours.map { "max. \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.name ?? SharingMessages.you).textStyle(.listTitle).foregroundStyle(Color.ink)
                    Text([application.headline, application.vacancyTitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .textStyle(.caption).foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 8)
                Text(NotificationInboxRow.when(application.appliedAt)).textStyle(.caption).foregroundStyle(Color.inkMuted)
            }
            if let why = application.why, !why.isEmpty {
                Text(why).textStyle(.bodyMedium).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
            }
            if let pitch = application.pitch, !pitch.isEmpty {
                Text("“\(pitch)”").textStyle(.caption).foregroundStyle(Color.inkMuted).italic().fixedSize(horizontal: false, vertical: true)
            }
            if !days.isEmpty {
                PaveIconLabel(icon: .iconVaultCalendarOutline, text: days)
            }
            switch (application.status, application.answer) {
            case ("invited", "accepted"?):
                Text(SharingMessages.inboxAccepted(application.invitedFor)).textStyle(.chip).foregroundStyle(Color.paveAccent)
            case ("invited", "declined"?):
                Text(SharingMessages.inboxDeclined).textStyle(.chip).foregroundStyle(Color.critical)
            case ("invited", _):
                Text(SharingMessages.inboxInvited(application.invitedFor)).textStyle(.chip).foregroundStyle(Color.inkMuted)
            default:
                PavePrimaryButton(title: SharingMessages.inboxInvite, action: onInvite)
            }
        }
        .padding(16)
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
    }
}
