import PAVECore
import SwiftUI

/// All applications in one list, from Ayla, made yourself and left at the fair, by where they stand: concept first, then
/// sent, interview, offer, and rejected last. Within a group the nearest deadline comes first. A tag says where each
/// comes from, and the chips on top show only one source. A tap opens the overview, or Mijn beursdag for the fair.
struct ApplicationsList: View {
    let applications: [ApplicationDraft]
    let onOpen: (Vacancy) -> Void
    /// Starts an application for a vacancy from elsewhere or an open one; nil where that cannot open the studio.
    var onNew: (() -> Void)?
    /// Removes an application from this device, after asking.
    var onDelete: ((ApplicationDraft) -> Void)?

    @State private var deleting: ApplicationDraft?
    @State private var source: ApplicationSource?
    @State private var showsFairDay = false
    @Environment(SharingModel.self) private var sharing: SharingModel?

    private var fair: [FairApplication] { sharing?.fairApplications ?? [] }

    private var sources: [ApplicationSource] {
        ApplicationSource.allCases.filter { kind in
            kind == .fair ? !fair.isEmpty : applications.contains { ApplicationSource($0.vacancy) == kind }
        }
    }

    private var groups: [(status: ApplicationStatus, drafts: [ApplicationDraft], fair: [FairApplication])] {
        ApplicationStatus.allCases.compactMap { status in
            let drafts = source == .fair ? [] : applications
                .filter { $0.progress.status == status && (source == nil || ApplicationSource($0.vacancy) == source) }
                .sorted(by: Self.isBefore)
            let left = source == nil || source == .fair
                ? fair.filter { $0.applicationStatus == status }.sorted { ($0.invitedFor ?? $0.createdAt) < ($1.invitedFor ?? $1.createdAt) }
                : []
            return drafts.isEmpty && left.isEmpty ? nil : (status, drafts, left)
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
            .sheet(isPresented: $showsFairDay) {
                if let sharing {
                    NavigationStack {
                        FairDayView(model: sharing)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) { Button(ApplyMessages.close) { showsFairDay = false } }
                            }
                    }
                }
            }
            .task { if sharing?.fairApplications == nil { await sharing?.loadFairApplications() } }
    }

    @ViewBuilder
    private var list: some View {
        if applications.isEmpty, fair.isEmpty {
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
                if sources.count > 1 { sourceChips }
                ForEach(groups, id: \.status) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(ApplyMessages.statusCount(group.status, group.drafts.count + group.fair.count))
                            .textStyle(.label)
                            .foregroundStyle(Color.inkMuted)
                            .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 10, alignment: .top)], spacing: 10) {
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
                            ForEach(group.fair) { application in
                                FairApplicationRow(application: application) { showsFairDay = true }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Alles, then one chip per source there is: Ayla, Zelf, Beurs.
    private var sourceChips: some View {
        FlowLayout(spacing: 8) {
            chip(ApplyMessages.sourceAll, isOn: source == nil) { source = nil }
            ForEach(sources, id: \.self) { kind in
                chip(ApplyMessages.source(kind), isOn: source == kind) { source = kind }
            }
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            PaveHaptics.selection()
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            Text(title)
                .textStyle(.chip)
                .foregroundStyle(isOn ? Color.white : Color.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(isOn ? Color.paveAccentFill : Color.panel, in: .capsule)
                .overlay { Capsule().strokeBorder(isOn ? Color.clear : Color.cardBorder) }
                .frame(minHeight: 44)
                .contentShape(.capsule)
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
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
