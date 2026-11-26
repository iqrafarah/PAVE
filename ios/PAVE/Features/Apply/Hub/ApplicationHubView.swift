import PAVECore
import SwiftUI

/// An application that was made before: its status, deadline and note, the CV and the letter to go on with, and what
/// to do next. The status is kept by hand; PAVE sends nothing to the company.
struct ApplicationHubView: View {
    let model: ApplicationStudioModel
    let photo: UIImage?
    /// What was shared for this application; nil where sharing is not available.
    var shares: [ProfileShare]?
    var onShare: (() -> Void)?
    var onOpenShare: (String) -> Void = { _ in }
    /// Changes when the invitation arrives while this is open, so it shows without leaving.
    @State private var tick = 0
    @State private var showsWholeVacancy = false
    let onTask: (AylaRequest.VacancyTask) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(ApplyMessages.hubTitle)
                    .textStyle(.emptyTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                // What you come back for first: where it stands, your CV and letter, sharing; next to it on a wide
                // screen (under it on a phone) keeping track, the vacancy and the employer.
                PaveColumns {
                    VStack(alignment: .leading, spacing: 20) {
                        ApplicationSummaryCard(draft: model.shown, shares: shares ?? [])
                        // Read here so the card comes in when it arrives, without rebuilding the page or losing the scroll.
                        let _ = tick
                        if let invitation = model.invitation {
                            ApplicationInvitationCard(model: model, invitation: invitation) { onTask(.interview) }
                        }
                        documents
                        if let onShare { sharing(onShare) }
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        ApplicationHubStatus(model: model)
                        let events = ApplicationTimeline.events(tracking: model.tracking, shares: shares ?? [])
                        if !events.isEmpty { ApplicationTimelineView(events: events) }
                        if let reports = model.shown.practice, !reports.isEmpty { practice(reports) }
                        if hasVacancyText { vacancyText }
                        employer
                        nextSteps
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .animation(.spring(duration: 0.45, bounce: 0.15), value: tick)
        .task(id: model.tracking.invitation?.arrivesAt) {
            guard let arrives = model.tracking.invitation?.arrivesAt, arrives > .now else { return }
            try? await Task.sleep(for: .seconds(arrives.timeIntervalSinceNow + 1))
            guard !Task.isCancelled else { return }
            PaveHaptics.success()
            tick += 1
        }
    }

    private var documents: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ApplyMessages.yourDocuments)
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: 14) {
                document(.cv, title: ApplyMessages.editCV)
                document(.letter, title: ApplyMessages.editLetter)
            }
            .frame(maxWidth: 420, alignment: .leading)
            Text(ApplyMessages.lastChanged(model.draft.updatedAt))
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
        }
    }

    private func document(_ kind: ApplicationDocumentKind, title: String) -> some View {
        Button { model.edit(kind) } label: {
            VStack(spacing: 8) {
                GeometryReader { proxy in
                    let scale = proxy.size.width / ApplicationPage.size.width
                    ApplicationPagePreview(draft: model.shown, document: kind, photo: kind == .cv ? photo : nil)
                        .equatable()
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: ApplicationPage.size.width * scale, height: ApplicationPage.size.height * scale, alignment: .topLeading)
                        .clipShape(.rect(cornerRadius: 4))
                        .drawingGroup()
                        .background { RoundedRectangle(cornerRadius: 4).fill(.white).shadow(color: .black.opacity(0.10), radius: 6, y: 3) }
                }
                .aspectRatio(ApplicationPage.size.width / ApplicationPage.size.height, contentMode: .fit)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                Text(title)
                    .textStyle(.chip)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(title)
    }

    private func sharing(_ onShare: @escaping () -> Void) -> some View {
        let company = model.draft.vacancy.company
        let made = shares ?? []
        return VStack(alignment: .leading, spacing: 10) {
            Text(ApplyMessages.shareTitle(company))
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(made.enumerated()), id: \.element.id) { index, share in
                    Button { onOpenShare(share.id) } label: { ShareRow(share: share) }
                        .buttonStyle(.pave)
                    ShareRowDivider(inset: index < made.count - 1 ? 60 : 0)
                }
                VStack(alignment: .leading, spacing: 12) {
                    if made.isEmpty {
                        Text(ApplyMessages.shareHint(company))
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        PavePrimaryButton(title: ApplyMessages.shareApplication, action: onShare)
                    } else {
                        PaveSecondaryButton(title: ApplyMessages.shareAgain, action: onShare)
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        }
    }

    private var hasVacancyText: Bool {
        model.draft.vacancy.url != nil || !(model.draft.vacancy.summary ?? "").isEmpty
    }

    /// What the vacancy asked, to read again before a talk: the piece PAVE has, and the whole one at the employer.
    private var vacancyText: some View {
        let vacancy = model.draft.vacancy
        return VStack(alignment: .leading, spacing: 10) {
            Text(ApplyMessages.theVacancy)
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 12) {
                if let summary = vacancy.summary, !summary.isEmpty {
                    Text(summary)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .lineLimit(showsWholeVacancy ? nil : 5)
                        .fixedSize(horizontal: false, vertical: true)
                    if summary.count > 260 {
                        Button(showsWholeVacancy ? ApplyMessages.showLess : ApplyMessages.showMore) {
                            withAnimation(.snappy(duration: 0.25)) { showsWholeVacancy.toggle() }
                        }
                        .textStyle(.chip)
                        .foregroundStyle(Color.paveAccent)
                        .buttonStyle(.pave)
                    }
                }
                if let url = vacancy.url {
                    Link(destination: url) {
                        HStack(spacing: 8) {
                            Text(AylaMessages.vacancyOpen)
                            Image(.iconArrowRight)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .accessibilityHidden(true)
                        }
                        .textStyle(.chip)
                        .foregroundStyle(Color.paveAccent)
                    }
                    .buttonStyle(.pave)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        }
    }

    private var employer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(EmployerMessages.title(model.draft.vacancy.company))
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            EmployerAboutSection(vacancy: model.draft.vacancy, service: model.lookupService)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.panel, in: .rect(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        }
    }

    private var nextSteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ApplyMessages.nextSteps)
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            let open = model.openRequirements
            VStack(alignment: .leading, spacing: 12) {
                if open.isEmpty {
                    Text(ApplyMessages.allCovered)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                } else {
                    Text(ApplyMessages.stillMissing(open.count))
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                    Text(open.prefix(4).map(\.skill).joined(separator: ", "))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.canWrite {
                        PaveSecondaryButton(title: ApplyMessages.whatCanIDo, icon: .iconPlus) { onTask(.gaps) }
                    }
                }
                if model.canWrite {
                    PaveSecondaryButton(title: ApplyMessages.practice, icon: .iconChatBubbleLeftEllipsisSolid) { onTask(.interview) }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        }
    }
}

extension ApplicationHubView {
    /// The practice interviews for this vacancy, the newest first; each opens its report.
    func practice(_ reports: [PracticeReport]) -> some View {
        SharePanel(title: ApplyMessages.practiceReports) {
            ForEach(Array(reports.reversed().enumerated()), id: \.element.id) { index, report in
                NavigationLink {
                    ScrollView {
                        PracticeReportView(report: report, vacancy: model.shown.vacancy)
                            .padding(20)
                            .frame(maxWidth: 640)
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color.canvas)
                    .navigationTitle(ApplyMessages.practiceReportTitle)
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(report.verdict).textStyle(.bodyMedium).foregroundStyle(Color.ink).lineLimit(2).multilineTextAlignment(.leading)
                            Text(ApplyMessages.practiceReportDate(report.madeAt)).textStyle(.caption).foregroundStyle(Color.inkMuted)
                        }
                        Spacer(minLength: 8)
                        Image(.iconChevronRightSolid).renderingMode(.template).resizable().scaledToFit().frame(width: 10, height: 10)
                            .foregroundStyle(Color.inkMuted).accessibilityHidden(true)
                    }
                    .padding(14)
                    .contentShape(.rect)
                }
                .buttonStyle(.pave)
                if index < reports.count - 1 { ShareRowDivider(inset: 14) }
            }
        }
    }
}
