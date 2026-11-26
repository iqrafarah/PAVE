import PAVECore
import SwiftUI

/// A card you left at the fair, in the one list of applications: the job, the employer, where it stands, and the tag
/// Beurs. A tap opens Mijn beursdag, where you answer an invitation.
struct FairApplicationRow: View {
    let application: FairApplication
    let action: () -> Void

    private var employer: String {
        FairDay.employerName(slug: application.employerSlug) ?? application.employerSlug.replacingOccurrences(of: "-", with: " ").capitalized
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                CompanyLogo(name: employer, url: nil, size: 44, city: nil, looksUp: true)
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(application.vacancyTitle)
                            .textStyle(.listTitle)
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.leading)
                        Text(employer)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    FlowLayout(spacing: 6) {
                        ApplicationSourceTag(source: .fair)
                        Text(SharingMessages.dayStatus(application))
                            .textStyle(.caption)
                            .foregroundStyle(application.awaitsAnswer ? Color.white : Color.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(application.awaitsAnswer ? Color.paveAccentFill : Color.canvas, in: .capsule)
                    }
                    if let moment = application.invitedFor {
                        Text(ApplyMessages.slot(moment))
                            .textStyle(.caption)
                            .foregroundStyle(Color.paveAccent)
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
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
    }
}
