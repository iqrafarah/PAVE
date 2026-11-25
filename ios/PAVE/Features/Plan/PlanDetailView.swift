import PAVECore
import SwiftUI

/// The page of one plan: its goal and progress, all steps, and its chats with Ayla. From here you go on with Ayla
/// (the latest chat of the plan, or a new one for the step you are on) and change the steps yourself.
struct PlanDetailView: View {
    let planID: String
    let chats: AylaConversationList
    let chatsAreComplete: Bool
    let actions: PlanChatActions

    @Environment(PlanModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStep: PavePlanStep?
    @State private var editedStep: PavePlanStep?
    @State private var addsStep = false
    @State private var editsPlan = false
    @State private var deletedPlan: PavePlan?
    @State private var deleteAfterEdit = false
    @AppStorage(PlanActivityController.showsNamesKey) private var showsNamesOnLockScreen = false

    private var plan: PavePlan? { model.plan(id: planID) }

    var body: some View {
        Group {
            if let plan {
                content(plan)
            } else {
                Color.canvas
            }
        }
        .background(Color.canvas.ignoresSafeArea())
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PaveTitle(PlanMessages.title)
                    .offset(y: 4)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(PlanMessages.rename, systemImage: "pencil") { editsPlan = true }
                    Button(PlanMessages.addStep, systemImage: "plus") { addsStep = true }
                    if plan?.isFinished == true {
                        Button(PlanMessages.reopen, systemImage: "arrow.uturn.backward") { model.reopen(planID) }
                    } else {
                        Button(PlanMessages.complete, systemImage: "checkmark") {
                            PaveHaptics.success()
                            model.complete(planID)
                        }
                    }
                    if model.canFollow, plan?.isFinished == false {
                        Section(PlanMessages.lockScreenSection) {
                            if model.isFollowed(planID) {
                                Button(PlanMessages.stopFollowing, systemImage: "lock.slash") { model.stopFollowing() }
                            } else {
                                Button(PlanMessages.followOnLockScreen, systemImage: "lock.iphone") { model.follow(planID) }
                            }
                            // Others can see the Lock Screen: names only when you choose so.
                            Toggle(PlanMessages.showNamesOnLockScreen, systemImage: "textformat", isOn: $showsNamesOnLockScreen)
                        }
                    }
                    Divider()
                    Button(PlanMessages.delete, systemImage: "trash", role: .destructive) { deletedPlan = plan }
                } label: {
                    Image(.iconEllipsis)
                        .renderingMode(.template)
                        .foregroundStyle(Color.ink)
                        .paveToolbarHitArea()
                }
                .accessibilityLabel("Meer")
            }
        }
        .onChange(of: showsNamesOnLockScreen) { model.refreshLiveActivity() }
        // A deleted plan closes its page.
        .onChange(of: plan == nil) { _, isGone in if isGone { dismiss() } }
        .sheet(isPresented: $editsPlan, onDismiss: {
            if deleteAfterEdit { deletedPlan = plan }
            deleteAfterEdit = false
        }) {
            if let plan {
                PlanEditor(plan: plan) { name, goal, _ in
                    await model.rename(plan.id, to: name, goal: goal)
                } onDelete: {
                    deleteAfterEdit = true
                }
                .paveSheet()
            }
        }
        .planDeletion($deletedPlan, chats: chats, chatsAreComplete: chatsAreComplete, actions: actions)
        .sheet(isPresented: $addsStep) {
            PlanStepEditor(step: nil) { step in model.addStep(step, to: planID) }
                .paveSheet()
        }
        .sheet(item: $editedStep) { step in
            PlanStepEditor(step: step) { changed in
                model.updateStep(changed, in: planID)
            } onDelete: {
                model.removeStep(step.id, from: planID)
            }
            .paveSheet()
        }
        .confirmationDialog(selectedStep?.title ?? "", isPresented: Binding(get: { selectedStep != nil }, set: { if !$0 { selectedStep = nil } }), titleVisibility: .visible, presenting: selectedStep) { step in
            stepActions(step)
        }
    }

    private func content(_ plan: PavePlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header(plan)
                steps(plan)
                conversations(plan)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .animation(.snappy, value: plan)
    }

    private func header(_ plan: PavePlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                PlanBadge(templateID: plan.templateID, size: 48)
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.name)
                        .textStyle(.title)
                        .foregroundStyle(Color.ink)
                    if !plan.goal.isEmpty {
                        Text(plan.goal)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
            if plan.totalCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    PlanProgressBar(progress: plan.progress)
                    Text("\(PlanMessages.progress(plan)) afgerond\(plan.steps.contains { $0.status == .skipped } ? " · \(PlanMessages.skippedNote)" : "")")
                        .textStyle(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.inkMuted)
                        .contentTransition(.numericText())
                }
            }
            HStack(spacing: 10) {
                if plan.isFinished {
                    PaveSoftButton(title: PlanMessages.reopen) { model.reopen(plan.id) }
                } else {
                    PavePrimaryButton(title: PlanMessages.resume) { resume(plan) }
                    PaveSoftButton(title: PlanMessages.newConversation) { actions.start(plan, plan.currentStep) }
                }
            }
            .padding(.top, 4)
        }
    }

    private func steps(_ plan: PavePlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(PlanMessages.steps)
            if plan.steps.isEmpty {
                Text(PlanMessages.noSteps)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            } else {
                PlanTimeline(steps: plan.steps, spacing: 18) { step in
                    selectedStep = step
                } trailing: { step in
                    Image(step.kind.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(14)
                        .foregroundStyle(step.status == .active ? Color.paveAccent : Color.inkMuted.opacity(0.7))
                        .padding(.top, 3)
                        .accessibilityHidden(true)
                }
                .padding(16)
                .background(Color.panel, in: .rect(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.cardBorder) }
            }
            Button {
                addsStep = true
            } label: {
                Label {
                    Text(PlanMessages.addStep).textStyle(.action)
                } icon: {
                    Image(.iconPlus).renderingMode(.template).resizable().scaledToFit().paveIconFrame(12)
                }
                .foregroundStyle(Color.paveAccent)
                .frame(minHeight: 44)
            }
            .buttonStyle(.pave)
        }
    }

    private func conversations(_ plan: PavePlan) -> some View {
        let chats = plan.liveConversations(in: chats, isComplete: chatsAreComplete)
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle(PlanMessages.conversations)
            if chats.isEmpty {
                Text(PlanMessages.noConversations)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(chats.enumerated()), id: \.element.id) { index, chat in
                        Button {
                            actions.open(chat.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(.iconChat)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .paveIconFrame(16)
                                    .foregroundStyle(Color.paveAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.title.isEmpty ? PlanMessages.untitledConversation(chats.count - index) : chat.title)
                                        .textStyle(.listTitle)
                                        .foregroundStyle(Color.ink)
                                        .lineLimit(1)
                                    if let step = plan.steps.first(where: { $0.id == chat.stepID }) {
                                        Text(step.title)
                                            .textStyle(.caption)
                                            .foregroundStyle(Color.inkMuted)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(.iconChevronRight)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 10, height: 10)
                                    .foregroundStyle(Color.inkMuted)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.pave)
                        .contextMenu {
                            Button(PlanMessages.detachConversation, systemImage: "minus.circle", role: .destructive) {
                                model.detach(conversationID: chat.id, from: plan.id)
                            }
                        }
                        if index < chats.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color.panel, in: .rect(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.cardBorder) }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .textStyle(.label)
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func stepActions(_ step: PavePlanStep) -> some View {
        if let plan {
            Button(PlanMessages.discussStep) { actions.start(plan, step) }
            if step.status != .done {
                Button(PlanMessages.markDone) { model.setStatus(.done, of: step.id, in: planID) }
            }
            if step.status != .active {
                Button(PlanMessages.markActive) { model.setStatus(.active, of: step.id, in: planID) }
            }
            if step.status == .done || step.status == .skipped {
                Button(PlanMessages.markUpcoming) { model.setStatus(.upcoming, of: step.id, in: planID) }
            }
            if step.status != .skipped, step.status != .done {
                Button(PlanMessages.markSkipped) { model.setStatus(.skipped, of: step.id, in: planID) }
            }
            if let destination = step.kind.destination {
                Button(destination.planStepAction) { actions.go(destination) }
            }
            if let chatID = step.conversationID {
                Button(PlanMessages.openStepChat) { actions.open(chatID) }
            }
            Button(PlanMessages.editStep) { editedStep = step }
        }
    }

    /// Back to the latest chat of the plan, or a new one for the step you are on.
    private func resume(_ plan: PavePlan) {
        if let latest = plan.liveConversations(in: chats, isComplete: chatsAreComplete).first {
            actions.open(latest.id)
        } else {
            actions.start(plan, plan.currentStep)
        }
    }
}
