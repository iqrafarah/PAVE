import PAVECore
import SwiftUI

/// What to do with the chats of a plan, from the Plan screen.
struct PlanChatActions {
    /// Opens an existing chat of the plan in Ayla.
    let open: (String) -> Void
    /// Starts a new chat with Ayla in the plan, optionally for one step.
    let start: (PavePlan, PavePlanStep?) -> Void
    /// Opens the place in PAVE where a step is done: the vault, the profile or Meldingen.
    var go: (MainDestination) -> Void = { _ in }
    /// Deletes these chats, when a plan is deleted together with its chats.
    var deleteChats: ([String]) -> Void = { _ in }
}

/// All plans: the ones still going, the most recently changed first, and below them the finished ones. A plan opens on
/// its own page; a swipe or a long press finishes, reopens or deletes it.
struct PlanScreen: View {
    let onShowMenu: (() -> Void)?
    /// The chats, to show the plan's chats with their current titles.
    let chats: AylaConversationList
    let chatsAreComplete: Bool
    let actions: PlanChatActions

    @Environment(PlanModel.self) private var model
    @State private var createsPlan = false
    @State private var editedPlan: PavePlan?
    @State private var deletedPlan: PavePlan?
    /// "Plan verwijderen" in the editor: asked once the editor is gone.
    @State private var deleteAfterEdit: PavePlan?

    private var path: Binding<[String]> {
        Binding(get: { model.openPlanID.map { [$0] } ?? [] }, set: { model.openPlanID = $0.last })
    }

    var body: some View {
        NavigationStack(path: path) {
            Group {
                if !model.isAvailable, model.plans.isEmpty {
                    unavailable
                } else if model.plans.isEmpty, model.hasLoaded {
                    empty
                } else {
                    list
                }
            }
            .background(Color.canvas.ignoresSafeArea())
            .mainScreenToolbar(PlanMessages.title, onShowMenu: onShowMenu)
            .toolbar {
                if !model.plans.isEmpty, model.isAvailable {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            createsPlan = true
                        } label: {
                            Image(.iconPlus)
                                .renderingMode(.template)
                                .foregroundStyle(Color.ink)
                                .paveToolbarHitArea()
                        }
                        .accessibilityLabel(PlanMessages.newPlan)
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                PlanDetailView(planID: id, chats: chats, chatsAreComplete: chatsAreComplete, actions: actions)
            }
        }
        // Not there yet the last time (a migration that ran since): try again whenever the screen opens.
        .task { if !model.isAvailable { await model.load() } }
        .sheet(isPresented: $createsPlan) {
            PlanEditor(plan: nil) { name, goal, template in
                guard let plan = await model.create(name: name, goal: goal, from: template) else { return false }
                if template.id == PlanTemplates.withAyla.id { model.proposesStepsFor = plan.id }
                model.openPlanID = plan.id
                return true
            }
            .paveSheet()
        }
        .sheet(item: $editedPlan, onDismiss: {
            deletedPlan = deleteAfterEdit
            deleteAfterEdit = nil
        }) { plan in
            PlanEditor(plan: plan) { name, goal, _ in
                await model.rename(plan.id, to: name, goal: goal)
            } onDelete: {
                deleteAfterEdit = plan
            }
            .paveSheet()
        }
        .planDeletion($deletedPlan, chats: chats, chatsAreComplete: chatsAreComplete, actions: actions)
        .alert(PlanMessages.title, isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.problem ?? "")
        }
    }

    private var empty: some View {
        ScrollView {
            VStack(spacing: 24) {
                PaveEmptyState(icon: .iconMap, title: PlanMessages.emptyTitle, message: PlanMessages.emptyMessage)
                PavePrimaryButton(title: PlanMessages.newPlan) { createsPlan = true }
                    .frame(maxWidth: 280)
            }
            .padding(.horizontal, 32)
            .containerRelativeFrame(.vertical)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Before the plans exist in Supabase: an honest note instead of a button that cannot save.
    private var unavailable: some View {
        ScrollView {
            PaveEmptyState(icon: .iconMap, title: PlanMessages.emptyTitle, message: PlanMessages.notAvailable)
                .padding(.horizontal, 32)
                .containerRelativeFrame(.vertical)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable { await model.load() }
    }

    /// A native list, for the swipe actions; the rows keep PAVE's own cards.
    private var list: some View {
        List {
            if !model.activePlans.isEmpty {
                Section {
                    ForEach(model.activePlans) { plan in row(plan) }
                } header: {
                    if !model.finishedPlans.isEmpty { sectionHeader(PlanMessages.activeSection) }
                }
            }
            if !model.finishedPlans.isEmpty {
                Section {
                    ForEach(model.finishedPlans) { plan in row(plan) }
                } header: {
                    sectionHeader(PlanMessages.finishedSection)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: model.plans.map { "\($0.id)\($0.isFinished)" })
        .refreshable { await model.refresh() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .textStyle(.label)
            .foregroundStyle(Color.inkMuted)
            .textCase(nil)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ plan: PavePlan) -> some View {
        Button {
            model.openPlanID = plan.id
        } label: {
            PlanCard(plan: plan, conversationCount: plan.liveConversations(in: chats, isComplete: chatsAreComplete).count)
        }
        .buttonStyle(.pave)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            finishButton(plan)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                deletedPlan = plan
            } label: {
                Label(PlanMessages.delete, systemImage: "trash")
            }
            .tint(.red)
        }
        .contextMenu {
            Button(PlanMessages.rename, systemImage: "pencil") { editedPlan = plan }
            if !plan.isFinished {
                Button(PlanMessages.newConversation, systemImage: "square.and.pencil") { actions.start(plan, plan.currentStep) }
            }
            finishButton(plan)
            Divider()
            Button(PlanMessages.delete, systemImage: "trash", role: .destructive) { deletedPlan = plan }
        }
    }

    @ViewBuilder
    private func finishButton(_ plan: PavePlan) -> some View {
        if plan.isFinished {
            Button {
                model.reopen(plan.id)
            } label: {
                Label(PlanMessages.reopen, systemImage: "arrow.uturn.backward")
            }
            .tint(.gray)
        } else {
            Button {
                PaveHaptics.success()
                model.complete(plan.id)
            } label: {
                Label(PlanMessages.complete, systemImage: "checkmark")
            }
            .tint(Color.paveAccent)
        }
    }
}

extension View {
    /// "Plan verwijderen?", with the choice to keep the plan's chats with Ayla or delete them too. Evidence in the vault
    /// is never touched: a plan only ever points at it.
    func planDeletion(_ plan: Binding<PavePlan?>, chats: AylaConversationList, chatsAreComplete: Bool, actions: PlanChatActions) -> some View {
        modifier(PlanDeletion(plan: plan, chats: chats, chatsAreComplete: chatsAreComplete, actions: actions))
    }
}

private struct PlanDeletion: ViewModifier {
    @Binding var plan: PavePlan?
    let chats: AylaConversationList
    let chatsAreComplete: Bool
    let actions: PlanChatActions

    @Environment(PlanModel.self) private var model

    private func chatIDs(of plan: PavePlan) -> [String] {
        plan.liveConversations(in: chats, isComplete: chatsAreComplete).map(\.id)
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            PlanMessages.deleteQuestion,
            isPresented: Binding(get: { plan != nil }, set: { if !$0 { plan = nil } }),
            titleVisibility: .visible,
            presenting: plan
        ) { plan in
            let ids = chatIDs(of: plan)
            if ids.isEmpty {
                Button(PlanMessages.delete, role: .destructive) { delete(plan, chats: []) }
            } else {
                Button(PlanMessages.deleteKeepChats) { delete(plan, chats: []) }
                Button(PlanMessages.deleteWithChats, role: .destructive) { delete(plan, chats: ids) }
            }
            Button("Annuleren", role: .cancel) {}
        } message: { plan in
            let count = chatIDs(of: plan).count
            Text(count == 0 ? PlanMessages.deleteBody : PlanMessages.deleteBody(chats: count))
        }
    }

    private func delete(_ plan: PavePlan, chats ids: [String]) {
        Task {
            await model.delete(plan.id)
            if !ids.isEmpty, model.plan(id: plan.id) == nil { actions.deleteChats(ids) }
        }
    }
}

/// The icon of the template a plan started from, in a soft tile, as the folders in the vault.
struct PlanBadge: View {
    let templateID: String?
    var size: CGFloat = 40

    var body: some View {
        Image(PlanTemplates.icon(for: templateID))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .paveIconFrame(size * 0.45)
            .foregroundStyle(Color.paveAccent)
            .paveIconFrame(size)
            .background(Color.paveSurfaceTint, in: .rect(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}

/// A plan in the list: its name and goal, one bar for how far it is and one line with the step you are on.
private struct PlanCard: View {
    let plan: PavePlan
    let conversationCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PlanBadge(templateID: plan.templateID)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.name)
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                    if !plan.goal.isEmpty {
                        Text(plan.goal)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(.iconChevronRight)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
            if plan.totalCount > 0 {
                PlanProgressBar(progress: plan.progress)
            }
            HStack(spacing: 6) {
                Text(plan.currentStep.map { "\(PlanMessages.stepNumber(plan)) · \($0.title)" } ?? (plan.isFinished ? PlanMessages.finished : PlanMessages.noSteps))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if conversationCount > 0 {
                    Text(PlanMessages.conversationCount(conversationCount))
                }
            }
            .textStyle(.caption)
            .foregroundStyle(Color.inkMuted)
        }
        .padding(16)
        .background(Color.panel, in: .rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.cardBorder) }
        .contentShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    @Previewable @State var model = PlanModel(service: LocalPlanService(fileURL: nil, seed: [PavePlan(template: PlanTemplates.job), PavePlan(template: PlanTemplates.certificate)]))
    PlanScreen(onShowMenu: {}, chats: AylaConversationList(), chatsAreComplete: false, actions: PlanChatActions(open: { _ in }, start: { _, _ in }))
        .environment(model)
        .task { await model.load() }
}
