import PAVECore
import SwiftUI

/// All applications, by where they stand: concept first, then sent, interview, offer, and rejected last. Within a group
/// the nearest deadline comes first. A tap opens that application's overview.
struct ApplicationsList: View {
    let applications: [ApplicationDraft]
    let onOpen: (Vacancy) -> Void
    /// Starts an application for a vacancy from elsewhere or an open one; nil where that cannot open the studio.
    var onNew: (() -> Void)?
    /// Removes an application from this device, after asking.
    var onDelete: ((ApplicationDraft) -> Void)?

    @State private var deleting: ApplicationDraft?

    private var groups: [(status: ApplicationStatus, drafts: [ApplicationDraft])] {
        ApplicationStatus.allCases.compactMap { status in
            let drafts = applications.filter { $0.progress.status == status }.sorted(by: Self.isBefore)
            return drafts.isEmpty ? nil : (status, drafts)
        }
    }

    /// A deadline before none, the nearest first; otherwise the one changed last.
    static func isBefore(_ a: ApplicationDraft, _ b: ApplicationDraft) -> Bool {
        switch (a.progress.deadline, b.progress.deadline) {
        case let (x?, y?) where x != y: x < y
        case (.some, .none): true
        case (.none, .some): false
        default: a.updatedAt > b.updatedAt
        }
    }

    var body: some View {
        list
            .confirmationDialog(ApplyMessages.deleteApplicationQuestion(deleting?.vacancy.company ?? ""), isPresented: deleteQuestion, titleVisibility: .visible) {
                Button(ApplyMessages.deleteApplication, role: .destructive) {
                    if let deleting { onDelete?(deleting) }
                    deleting = nil
                }
            } message: {
                Text(ApplyMessages.deleteApplicationHint)
            }
    }

    @ViewBuilder
    private var list: some View {
        if applications.isEmpty {
            VStack(spacing: 16) {
                PaveEmptyState(icon: .iconBriefcase, title: ApplyMessages.applicationsEmptyTitle, message: ApplyMessages.applicationsEmpty)
                if let onNew {
                    PaveSecondaryButton(title: ApplyMessages.newApplication, action: onNew)
                        .frame(maxWidth: 260)
                }
            }
            .padding(.vertical, 16)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                if let onNew { newButton(onNew) }
                ForEach(groups, id: \.status) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(ApplyMessages.statusCount(group.status, group.drafts.count))
                            .textStyle(.label)
                            .foregroundStyle(Color.inkMuted)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.drafts) { draft in
                            ApplicationRow(draft: draft) { onOpen(draft.vacancy) }
                                .accessibilityActions {
                                    if onDelete != nil { Button(ApplyMessages.deleteApplication) { deleting = draft } }
                                }
                                .contextMenu {
                                    if onDelete != nil {
                                        Button(role: .destructive) { deleting = draft } label: { Label(ApplyMessages.deleteApplication, image: .iconTrash) }
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    private var deleteQuestion: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func newButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(.iconPlus)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(16)
                    .foregroundStyle(Color.paveAccent)
                    .paveIconFrame(44)
                    .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                Text(ApplyMessages.newApplication)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.pave)
    }
}
