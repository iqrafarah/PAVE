import PAVECore
import SwiftUI

/// One applicant's card as the employer sees it, with the button to invite.
struct EmployerInboxCard: View {
    let application: InboxApplication
    let onInvite: () -> Void

    @Environment(\.openURL) private var openURL

    /// The applicant's shared profile on the web, when they let it go along.
    private var profileURL: URL? {
        guard let code = application.profileCode, let base = ShareServiceFactory.webURL() else { return nil }
        return ShareLinks.share(code, base: base)
    }

    private var days: String {
        let short = application.availability.days.compactMap { Availability.Day(rawValue: $0) }.map(SharingMessages.day).joined(separator: ", ")
        let hours = application.availability.maxHours.map { SharingMessages.hours($0) }
        return [short.isEmpty ? nil : short, hours.map { "max. \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                photo
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
            if let profileURL {
                PaveSecondaryButton(title: SharingMessages.inboxOpenProfile, icon: .iconUserSolid) { openURL(profileURL) }
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

    /// Their photo when they showed it, else a plain person.
    private var photo: some View {
        AsyncImage(url: application.photo) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(.iconUserSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(20)
                .foregroundStyle(Color.paveAccent)
        }
        .frame(width: 48, height: 48)
        .background(Color.paveSurfaceTint)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}
