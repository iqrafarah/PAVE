import PAVECore
import SwiftUI

/// Meldingen › Van de beurs: an employer at the fair invites you. You answer here, put the talk in your calendar and
/// start practising with Ayla right from the row; a tap on the row opens the application itself. Its own section and
/// file, so the rest of Meldingen stays as it is.
struct NotificationFairSection: View {
    let sharing: SharingModel
    @Binding var isCollapsed: Bool

    @State private var calendarFor: FairApplication?
    @State private var opened: OpenedApplication?
    @Environment(\.vacancyRequest) private var vacancyRequest

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
                if !isCollapsed {
                    ForEach(invitations) { application in
                        FairInvitationRow(application: application, employer: FairApplicationDetail.employerName(application)) { accepted in
                            Task { await sharing.answer(application, accepted: accepted) }
                        } onCalendar: {
                            calendarFor = application
                        } onPractise: {
                            vacancyRequest?(.task(.interview, FairApplicationDetail.vacancy(of: application)))
                        } onOpen: {
                            opened = OpenedApplication(id: application.id)
                        }
                        .listRowBackground(Color.panel)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
            } header: {
                NotificationSectionHeader(title: SharingMessages.notificationsFair, count: invitations.count, isCollapsed: $isCollapsed)
                    .sheet(item: $calendarFor) { application in
                        if let moment = application.invitedFor {
                            ApplicationCalendarEditor(vacancy: FairApplicationDetail.vacancy(of: application), deadline: moment, isTalk: true) { calendarFor = nil }
                                .ignoresSafeArea()
                        }
                    }
                    .sheet(item: $opened) { application in
                        NavigationStack {
                            FairApplicationDetail(model: sharing, applicationID: application.id)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) { Button(ApplyMessages.close) { opened = nil } }
                                }
                        }
                    }
            }
        }
    }

    private struct OpenedApplication: Identifiable { let id: String }
}
