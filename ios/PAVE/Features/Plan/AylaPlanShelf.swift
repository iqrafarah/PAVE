import PAVECore
import SwiftUI

/// The Plan page when Ayla opens it over the chat ("open mijn plan", the start chip): the same plans as in the menu,
/// where you can make one, open one and go on with Ayla. Going on with Ayla closes the page and the chat continues in
/// the plan; a step in the vault, profile or Meldingen opens that page instead.
struct AylaPlanShelf: View {
    let chat: AylaChatModel
    /// Closes the page, then does this.
    let onLeave: (@escaping () -> Void) -> Void
    /// Opens another page over the chat.
    let onOpen: (AylaShelf) -> Void

    var body: some View {
        PlanScreen(
            onShowMenu: nil,
            chats: chat.conversationList,
            chatsAreComplete: chat.hasLoadedList && !chat.canLoadMore && !chat.listFailed,
            actions: PlanChatActions(
                open: { id in
                    onLeave {
                        let conversation = chat.conversationList.conversations.first { $0.id == id }
                            ?? AylaConversation(id: id, title: "", updatedAt: .now)
                        Task { await chat.open(conversation) }
                    }
                },
                start: { plan, step in
                    onLeave {
                        chat.newConversation(in: chat.conversationList.projects.first { $0.id == plan.projectID }, plan: plan.id, step: step?.id)
                        if let step { chat.draft = PlanMessages.stepPrompt(step) }
                    }
                },
                go: { destination in
                    switch destination {
                    case .vault: onOpen(.vault)
                    case .profile: onOpen(.profile)
                    case .notifications: onOpen(.notifications)
                    default: break
                    }
                },
                deleteChats: { ids in
                    let chats = chat.conversationList.conversations.filter { ids.contains($0.id) }
                    if !chats.isEmpty {
                        chat.delete(chats)
                        chat.commitPendingDeletion()
                    }
                }
            )
        )
    }
}

/// "Plan toevoegen" from the plus button: puts the chat in one of your plans, or in a new one. A chat that has not
/// begun yet starts in the plan with its first message.
struct PlanPickerSheet: View {
    let currentPlanID: String?
    let onPick: (PavePlan) -> Void
    let onLeavePlan: () -> Void

    @Environment(PlanModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var createsPlan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(PlanMessages.choosePlanHint)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.bottom, 4)
                    if !model.isAvailable {
                        PaveEmptyState(icon: .iconMap, title: PlanMessages.emptyTitle, message: PlanMessages.notAvailable)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                    ForEach(model.orderedPlans) { plan in
                        row(plan)
                    }
                    if model.isAvailable {
                        Button {
                            createsPlan = true
                        } label: {
                            Label {
                                Text(PlanMessages.newPlan).textStyle(.action)
                            } icon: {
                                Image(.iconPlus).renderingMode(.template).resizable().scaledToFit().paveIconFrame(12)
                            }
                            .foregroundStyle(Color.paveAccent)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.pave)
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(PlanMessages.choosePlan)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                if currentPlanID != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(PlanMessages.detachConversation, role: .destructive) {
                            onLeavePlan()
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $createsPlan) {
                PlanEditor(plan: nil) { name, goal, template in
                    guard let plan = await model.create(name: name, goal: goal, from: template) else { return false }
                    onPick(plan)
                    dismiss()
                    return true
                }
                .paveSheet()
            }
            .task { if !model.hasLoaded { await model.load() } }
        }
        .tint(.paveAccent)
    }

    private func row(_ plan: PavePlan) -> some View {
        let isCurrent = plan.id == currentPlanID
        return Button {
            PaveHaptics.tap(.light)
            onPick(plan)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                PlanBadge(templateID: plan.templateID, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Text(plan.currentStep.map { "\(PlanMessages.stepNumber(plan)) · \($0.title)" } ?? (plan.isFinished ? PlanMessages.finished : PlanMessages.noSteps))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PlanStepMark(status: isCurrent ? .done : .upcoming)
            }
            .padding(12)
            .background(Color.panel, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isCurrent ? Color.paveAccent : Color.cardBorder, lineWidth: isCurrent ? 1.5 : 1)
            }
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
