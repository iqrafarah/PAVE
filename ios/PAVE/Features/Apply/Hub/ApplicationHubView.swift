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
    let onTask: (AylaRequest.VacancyTask) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // What you come back for first: where it stands, your CV and letter, sharing; then keeping track.
                Text(ApplyMessages.hubTitle)
                    .textStyle(.emptyTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                ApplicationSummaryCard(draft: model.shown, shares: shares ?? [])
                if let invitation = model.invitation {
                    ApplicationInvitationCard(model: model, invitation: invitation) { onTask(.interview) }
                }
                documents
                if let onShare { sharing(onShare) }
                ApplicationHubStatus(model: model)
                if model.tracking.history.count > 0 { history }
                employer
                nextSteps
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .id(tick)
        .task(id: model.tracking.invitation?.arrivesAt) {
            guard let arrives = model.tracking.invitation?.arrivesAt, arrives > .now else { return }
            try? await Task.sleep(for: .seconds(arrives.timeIntervalSinceNow + 1))
            guard !Task.isCancelled else { return }
            PaveHaptics.success()
            tick += 1
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ApplyMessages.history)
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(model.tracking.history.reversed().enumerated()), id: \.offset) { index, change in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(index == 0 ? Color.paveAccent : Color.inkMuted.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(ApplyMessages.historyLine(change))
                            .textStyle(.bodyMedium)
                            .foregroundStyle(index == 0 ? Color.ink : Color.inkMuted)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
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
                        PavePrimaryButton(title: ApplyMessages.shareWith(company), action: onShare)
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
