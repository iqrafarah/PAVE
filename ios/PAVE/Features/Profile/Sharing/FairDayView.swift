import PAVECore
import SwiftUI

/// Mijn beursdag: invitations to answer first, then where you left your card and which stands you scanned today, with
/// what is still worth doing.
struct FairDayView: View {
    let model: SharingModel

    @Environment(\.vacancyRequest) private var vacancyRequest
    @State private var entries: [FairDay.Entry] = []
    @State private var calendarFor: FairApplication?
    @State private var sharesBackWith: String?
    @State private var showsShareBack = false

    private var applications: [FairApplication] { model.fairApplications ?? [] }
    private var invitations: [FairApplication] { applications.filter { $0.status == .invited } }
    private var scannedNotApplied: [(name: String, slug: String, stand: String?)] {
        var seen = Set<String>()
        return entries.compactMap { entry -> (String, String, String?)? in
            guard case .scanned(let name, let slug, let stand) = entry.event, !applications.contains(where: { $0.employerSlug == slug }), seen.insert(slug).inserted else { return nil }
            return (name, slug, stand)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "nl_NL"))))
                    .textStyle(.bodyMedium).foregroundStyle(Color.inkMuted)
                if !invitations.isEmpty {
                    SharePanel(title: SharingMessages.dayInvitations) {
                        ForEach(invitations) { application in
                            FairInvitationRow(application: application, employer: employerName(application)) { accepted in
                                Task { await model.answer(application, accepted: accepted) }
                            } onCalendar: {
                                calendarFor = application
                            } onPractise: {
                                vacancyRequest?(.task(.interview, vacancy(of: application)))
                            }
                            ShareRowDivider(inset: 14)
                        }
                    }
                }
                if !applications.isEmpty {
                    SharePanel(title: SharingMessages.dayLeft) {
                        ForEach(applications) { application in
                            NavigationLink { employerCard(application.employerSlug) } label: {
                                HStack(spacing: 14) {
                                    ShareRowIcon(icon: .iconBriefcaseSolid)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(application.vacancyTitle).textStyle(.bodyMedium).foregroundStyle(Color.ink).lineLimit(2)
                                        Text(employerName(application)).textStyle(.caption).foregroundStyle(Color.inkMuted)
                                        Text(SharingMessages.dayStatus(application)).textStyle(.caption).foregroundStyle(application.awaitsAnswer ? Color.paveAccent : Color.inkMuted)
                                    }
                                    .multilineTextAlignment(.leading)
                                    Spacer(minLength: 8)
                                    chevron
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.pave)
                            ShareRowDivider()
                        }
                    }
                }
                if !scannedNotApplied.isEmpty {
                    SharePanel(title: SharingMessages.dayNext) {
                        ForEach(scannedNotApplied, id: \.slug) { stand in
                            NavigationLink { employerCard(stand.slug) } label: {
                                HStack(spacing: 14) {
                                    ShareRowIcon(icon: .iconQrcode, isMuted: true)
                                    Text(SharingMessages.dayNotApplied(stand.name, stand: stand.stand))
                                        .textStyle(.bodyMedium)
                                        .foregroundStyle(Color.ink)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 8)
                                    chevron
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.pave)
                        }
                    }
                }
                if applications.isEmpty, entries.isEmpty {
                    PaveEmptyState(icon: .iconQrcode, title: SharingMessages.dayEmpty, message: SharingMessages.dayEmptyHint)
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas)
        .navigationTitle(SharingMessages.fairDay)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.loadFairApplications() }
        .task {
            entries = FairDay.all()
            // While you are at the fair, an invitation shows up here without pulling.
            while !Task.isCancelled {
                await model.loadFairApplications()
                try? await Task.sleep(for: .seconds(10))
            }
        }
        .sheet(isPresented: $showsShareBack) {
            ShareComposer(model: model, template: .fair, recipientOrganisation: sharesBackWith, withApplication: false) { showsShareBack = false }
        }
        .sheet(item: $calendarFor) { application in
            if let moment = application.invitedFor {
                ApplicationCalendarEditor(vacancy: vacancy(of: application), deadline: moment, isTalk: true) { calendarFor = nil }
                    .ignoresSafeArea()
            }
        }
    }

    private var chevron: some View {
        Image(.iconChevronRightSolid)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 10, height: 10)
            .foregroundStyle(Color.inkMuted)
            .accessibilityHidden(true)
    }

    /// The stand again, to apply after all or share your profile with them.
    private func employerCard(_ slug: String) -> some View {
        FairEmployerLoader(slug: slug, model: model) { employer in
            sharesBackWith = employer.name
            showsShareBack = true
        }
    }

    private func employerName(_ application: FairApplication) -> String {
        entries.compactMap { entry -> String? in
            if case .scanned(let name, let slug, _) = entry.event, slug == application.employerSlug { return name }
            return nil
        }.first ?? application.employerSlug.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private func vacancy(of application: FairApplication) -> Vacancy {
        Vacancy(id: application.vacancyID, title: application.vacancyTitle, company: employerName(application), source: .web)
    }
}
