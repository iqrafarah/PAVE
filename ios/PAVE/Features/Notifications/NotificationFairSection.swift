import PAVECore
import SwiftUI

/// Meldingen › Van de beurs: an employer at the fair invites you. You answer here, where every other message is; the
/// agenda and practising are in Mijn beursdag. Its own section and file, so the rest of Meldingen stays as it is.
struct NotificationFairSection: View {
    let sharing: SharingModel

    @Environment(\.openDestination) private var openDestination

    /// Waiting for your answer first, then the talks you said yes to that are still to come.
    static func shown(_ applications: [FairApplication], now: Date = .now) -> [FairApplication] {
        let waiting = applications.filter(\.awaitsAnswer)
        let coming = applications.filter { $0.answer == .accepted && ($0.invitedFor ?? .distantPast) > now }
        return waiting + coming
    }

    private var invitations: [FairApplication] { Self.shown(sharing.fairApplications ?? []) }

    var body: some View {
        if !invitations.isEmpty {
            Section {
                ForEach(invitations) { application in
                    FairInvitationRow(
                        application: application,
                        employer: FairDay.employerName(slug: application.employerSlug)
                            ?? application.employerSlug.replacingOccurrences(of: "-", with: " ").capitalized
                    ) { accepted in
                        Task { await sharing.answer(application, accepted: accepted) }
                    } onCalendar: {
                        openFairDay()
                    } onPractise: {
                        openFairDay()
                    }
                    .listRowBackground(Color.panel)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            } header: {
                Text(SharingMessages.notificationsFair)
                    .textStyle(.caption)
                    .foregroundStyle(Color.paveAccent)
                    .textCase(nil)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private func openFairDay() {
        sharing.showsFairDay = true
        openDestination?(.profile)
    }
}
