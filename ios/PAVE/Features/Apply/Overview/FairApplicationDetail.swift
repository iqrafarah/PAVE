import PAVECore
import SwiftUI

/// One application you left at the fair, opened from the list of applications: the job, where it stands, the
/// invitation to answer, and what the employer got from you. Mijn beursdag, with everything of the day, stays in Profiel.
struct FairApplicationDetail: View {
    let model: SharingModel
    let applicationID: String

    @State private var calendarFor: FairApplication?
    @Environment(\.vacancyRequest) private var vacancyRequest

    private var application: FairApplication? { model.fairApplications?.first { $0.id == applicationID } }

    var body: some View {
        ScrollView {
            if let application {
                let employer = Self.employerName(application)
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 14) {
                        CompanyLogo(name: employer, url: nil, size: 52, city: nil, looksUp: true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(application.vacancyTitle).textStyle(.emptyTitle).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                            Text(employer).textStyle(.bodyMedium).foregroundStyle(Color.inkMuted)
                            FlowLayout(spacing: 6) {
                                ApplicationSourceTag(source: .fair)
                                Text(SharingMessages.dayStatus(application))
                                    .textStyle(.caption)
                                    .foregroundStyle(application.awaitsAnswer ? Color.white : Color.ink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(application.awaitsAnswer ? Color.paveAccentFill : Color.panel, in: .capsule)
                            }
                        }
                    }
                    if application.status == .invited {
                        SharePanel(title: SharingMessages.fairDetailInvitation) {
                            FairInvitationRow(application: application, employer: employer) { accepted in
                                Task { await model.answer(application, accepted: accepted) }
                            } onCalendar: {
                                calendarFor = application
                            } onPractise: {
                                vacancyRequest?(.task(.interview, Self.vacancy(of: application)))
                            }
                        }
                    }
                    SharePanel(title: SharingMessages.fairDetailLeft) {
                        if !application.card.why.isEmpty { row(SharingMessages.quickApplyWhy, application.card.why) }
                        if !application.card.pitch.isEmpty { row(SharingMessages.fairDetailPitch, application.card.pitch) }
                        if !application.card.availability.isEmpty {
                            row(SharingMessages.availability, SharingMessages.availabilitySummary(application.card.availability))
                        }
                        row(
                            SharingMessages.quickApplyProfile,
                            application.card.profileCode == nil ? SharingMessages.fairDetailNoProfile : SharingMessages.fairDetailWithProfile
                        )
                    }
                    Text(SharingMessages.fairDetailFooter(application.createdAt))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            } else {
                PaveEmptyState(icon: .iconBriefcase, title: SharingMessages.fairDetailGone, message: SharingMessages.fairDetailGoneHint)
                    .padding(.top, 60)
            }
        }
        .background(Color.canvas)
        .navigationTitle(SharingMessages.fairDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $calendarFor) { application in
            if let moment = application.invitedFor {
                ApplicationCalendarEditor(vacancy: Self.vacancy(of: application), deadline: moment, isTalk: true) { calendarFor = nil }
                    .ignoresSafeArea()
            }
        }
    }

    private func row(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).textStyle(.caption).foregroundStyle(Color.inkMuted)
            Text(text).textStyle(.bodyMedium).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func employerName(_ application: FairApplication) -> String {
        FairDay.employerName(slug: application.employerSlug) ?? application.employerSlug.replacingOccurrences(of: "-", with: " ").capitalized
    }

    static func vacancy(of application: FairApplication) -> Vacancy {
        Vacancy(id: application.vacancyID, title: application.vacancyTitle, company: employerName(application), source: .web)
    }
}
