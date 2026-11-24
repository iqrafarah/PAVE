import PAVECore
import SwiftUI

/// All applications, by where they stand: concept first, then sent, interview, offer, and rejected last. Within a group
/// the nearest deadline comes first. A tap opens that application's overview.
struct ApplicationsList: View {
    let applications: [ApplicationDraft]
    let onOpen: (Vacancy) -> Void

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
        if applications.isEmpty {
            PaveEmptyState(icon: .iconBriefcase, title: ApplyMessages.applicationsEmptyTitle, message: ApplyMessages.applicationsEmpty)
                .padding(.vertical, 16)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groups, id: \.status) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(ApplyMessages.statusCount(group.status, group.drafts.count))
                            .textStyle(.label)
                            .foregroundStyle(Color.inkMuted)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.drafts) { draft in
                            ApplicationRow(draft: draft) { onOpen(draft.vacancy) }
                        }
                    }
                }
            }
        }
    }
}
