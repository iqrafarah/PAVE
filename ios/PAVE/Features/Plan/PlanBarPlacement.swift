import PAVECore
import SwiftUI

extension EnvironmentValues {
    /// Opens a plan on the Plan screen, from the Dynamic Bar in the chat.
    @Entry var openPlan: ((String) -> Void)?
}

extension View {
    /// Pins the Dynamic Bar of the chat's plan just under Ayla's header. The chat makes room for the small pill only;
    /// unfolded it lies over the chat, so the conversation never jumps, and a tap next to it folds it again.
    func planBar(chat: AylaChatModel, isHidden: Bool) -> some View {
        modifier(PlanBarPlacement(chat: chat, isHidden: isHidden))
    }

    /// Loads the plans, puts a new chat that was started in a plan into it as soon as the chat has an id, keeps the
    /// titles of the plan's chats the same as in the list of chats, and follows the steps Ayla changes: at once from
    /// her answer (updatePlan), and from Supabase after every answer in a plan's chat.
    func followsPlans(_ plans: PlanModel, chat: AylaChatModel) -> some View {
        task { await plans.load() }
            .onChange(of: chat.conversationID) { _, id in
                guard let id, let pending = chat.newChatPlan else { return }
                plans.attach(conversationID: id, stepID: pending.stepID, to: pending.planID)
            }
            .onChange(of: chat.conversationList) { _, list in plans.follow(list) }
            .onChange(of: chat.lastReply?.id) {
                // Only an answer that just came in: opening an older chat never applies its changes again.
                guard let entry = chat.entries.last(where: { $0.role == .ayla }), let reply = entry.reply,
                      Date.now.timeIntervalSince(entry.sentAt) < 120 else { return }
                if let update = reply.proposedAction?.planStep { plans.apply(update) }
                if plans.plan(containing: chat.conversationID) != nil || reply.proposedAction?.kind == .updatePlan {
                    Task { await plans.refresh() }
                }
            }
    }
}

private struct PlanBarPlacement: ViewModifier {
    let chat: AylaChatModel
    let isHidden: Bool

    @Environment(PlanModel.self) private var plans: PlanModel?
    /// Around the Dynamic Island instead (PlanIslandOverlay); then this only says when the plan should step aside.
    @Environment(\.plansInIsland) private var inIsland
    @Environment(\.openPlan) private var openPlan
    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var foldedHeight = PlanDynamicBar.pillHeight

    private var plan: PavePlan? {
        guard !isHidden, !inIsland else { return nil }
        return plans?.activePlan(conversationID: chat.conversationID, newChatPlanID: chat.newChatPlan?.planID)
    }

    private var chatsAreComplete: Bool {
        chat.hasLoadedList && !chat.canLoadMore && !chat.listFailed
    }

    func body(content: Content) -> some View {
        content
            .preference(key: PlanIslandHiddenKey.self, value: isHidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: plan == nil ? 0 : foldedHeight + 10)
            }
            .overlay(alignment: .top) {
                if let plan {
                    ZStack(alignment: .top) {
                        if isExpanded {
                            Color.clear
                                .contentShape(.rect)
                                .onTapGesture { setExpanded(false) }
                                .accessibilityHidden(true)
                        }
                        bar(plan)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.12), value: plan?.id)
            .onChange(of: chat.conversationID) { setExpanded(false) }
    }

    private func bar(_ plan: PavePlan) -> some View {
        PlanDynamicBar(
            plan: plan,
            conversations: plan.liveConversations(in: chat.conversationList, isComplete: chatsAreComplete),
            currentConversationID: chat.conversationID,
            isExpanded: $isExpanded,
            onOpenPlan: {
                setExpanded(false)
                openPlan?(plan.id)
            },
            onCompleteStep: { plans?.completeCurrentStep(in: plan.id) },
            onOpenConversation: { id in
                setExpanded(false)
                let conversation = chat.conversationList.conversations.first { $0.id == id }
                    ?? AylaConversation(id: id, title: "", updatedAt: .now)
                Task { await chat.open(conversation) }
            },
            onNewConversation: {
                setExpanded(false)
                chat.newConversation(plan: plan.id, step: plan.currentStep?.id)
            }
        )
        // The chat keeps room for the pill only: unfolding lies over the chat and never moves it. The pill stays pinned
        // while the chat scrolls under it.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            if !isExpanded { foldedHeight = height }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.12)) { isExpanded = value }
    }
}
