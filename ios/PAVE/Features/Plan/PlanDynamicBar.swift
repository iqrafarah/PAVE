import PAVECore
import SwiftUI

/// The plan of the open chat, pinned just under Ayla's header (on the web the steps are in the chat sidebar). Folded it
/// is a small pill in the middle, like the Dynamic Island: how far you are, the plan's name and the step you are on.
/// A tap morphs it into a card with every step, the chats of the plan and "Open plan". When a step is finished, here
/// or by Ayla, the pill briefly swells and says so.
struct PlanDynamicBar: View {
    let plan: PavePlan
    /// The chats of the plan that still exist, newest first.
    let conversations: [PavePlanConversation]
    /// The chat that is open, so it is not offered again.
    let currentConversationID: String?
    @Binding var isExpanded: Bool
    let onOpenPlan: () -> Void
    let onCompleteStep: () -> Void
    let onOpenConversation: (String) -> Void
    let onNewConversation: () -> Void

    @Environment(\.paveReduceMotion) private var reduceMotion
    @Namespace private var glass
    @State private var stepsHeight: CGFloat = 0
    /// The step that was just finished, shown for a moment.
    @State private var finished: PavePlanStep?
    @State private var swells = false

    static let pillHeight: CGFloat = 44

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.2)
    }

    var body: some View {
        GlassEffectContainer {
            if isExpanded {
                card
                    .glassEffect(.regular.tint(Color.panel.opacity(0.82)), in: .rect(cornerRadius: 26))
                    .glassEffectID("plan", in: glass)
                    .frame(maxWidth: 560)
            } else {
                pill
                    .glassEffect(.regular.tint(Color.panel.opacity(0.82)).interactive(), in: .capsule)
                    .glassEffectID("plan", in: glass)
                    .scaleEffect(swells ? 1.06 : 1)
                    // The glass hugs what is in it; a long name is cut before the pill gets wider than this.
                    .frame(maxWidth: 360)
            }
        }
        .sensoryFeedback(.success, trigger: plan.doneCount) { old, new in new > old }
        .onChange(of: plan.doneCount) { old, new in
            guard new > old, let step = lastFinished else { return }
            celebrate(step)
        }
    }

    private func toggle() {
        PaveHaptics.tap(.light)
        withAnimation(animation) { isExpanded.toggle() }
    }

    // MARK: Folded

    /// Only what you need at a glance: the ring, the plan's name and the step, and how far you are.
    private var pill: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                if let finished {
                    PlanStepMark(status: .done, size: 24)
                    Text(PlanMessages.stepFinished)
                        .textStyle(.chip)
                        .foregroundStyle(Color.paveAccent)
                    Text(finished.title)
                        .textStyle(.caption)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                } else {
                    PlanProgressRing(plan: plan, size: 24)
                    ViewThatFits(in: .horizontal) {
                        pillText.fixedSize()
                        pillText
                    }
                    if plan.totalCount > 0 {
                        Text(PlanMessages.shortProgress(plan))
                            .textStyle(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color.inkMuted)
                            .contentTransition(.numericText())
                            .fixedSize()
                    }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .frame(height: Self.pillHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(PlanMessages.showSteps)
        .accessibilityAddTraits(.isButton)
    }

    private var pillText: some View {
        HStack(spacing: 5) {
            Text(plan.name)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .lineLimit(1)
            if let step = plan.currentStep {
                Text("·")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                Text(step.title)
                    .textStyle(.chip)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
                    .contentTransition(.opacity)
            }
        }
    }

    // MARK: Unfolded

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: toggle) {
                HStack(spacing: 12) {
                    PlanProgressRing(plan: plan, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(subtitle)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                        Text(plan.name)
                            .textStyle(.chip)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(.iconChevronDown)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconHeight(6)
                        .foregroundStyle(Color.inkMuted)
                        .rotationEffect(.degrees(180))
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(PlanMessages.hideSteps)

            ScrollView {
                Group {
                    if plan.steps.isEmpty {
                        Text(PlanMessages.noSteps)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        PlanTimeline(steps: plan.steps, spacing: 12) { step in
                            if step.status == .active {
                                Button(PlanMessages.markDone, action: onCompleteStep)
                                    .textStyle(.tag)
                                    .foregroundStyle(Color.paveAccent)
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 28)
                                    .background(Color.paveSurfaceTint, in: .capsule)
                                    .buttonStyle(.pave)
                            }
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { stepsHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            // Never more than about half of the chat: the conversation stays the main thing.
            .frame(height: min(max(stepsHeight, 20), 280))

            HStack(spacing: 8) {
                PlanChatsMenu(conversations: conversations, currentConversationID: currentConversationID, onOpen: onOpenConversation, onNew: onNewConversation)
                Spacer(minLength: 0)
                Button(action: onOpenPlan) {
                    HStack(spacing: 6) {
                        Text(PlanMessages.openPlan)
                            .textStyle(.tag)
                        Image(.iconArrowRight)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .paveIconFrame(10)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 34)
                    .background(Color.paveAccentFill, in: .capsule)
                }
                .buttonStyle(.pave)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    /// Where you are in numbers; in the card only, the pill has its own short count.
    private var subtitle: String {
        if plan.isFinished { return PlanMessages.finished }
        return plan.currentStep == nil ? PlanMessages.noSteps : "\(PlanMessages.stepNumber(plan)) · \(PlanMessages.progress(plan)) afgerond"
    }

    private var accessibilityLabel: String {
        var words = "\(PlanMessages.title) \(plan.name)"
        if let step = plan.currentStep { words += ". \(PlanMessages.stepNumber(plan)): \(step.title)" }
        words += ". \(PlanMessages.progress(plan)) afgerond"
        return words
    }

    // MARK: Finishing a step

    private var lastFinished: PavePlanStep? {
        plan.steps.filter { $0.status == .done }.max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    /// A short swell of the pill with the finished step, then back to the step that is next.
    private func celebrate(_ step: PavePlanStep) {
        withAnimation(animation) { finished = step }
        if !reduceMotion, !isExpanded {
            withAnimation(.spring(duration: 0.25, bounce: 0.5)) { swells = true }
            withAnimation(.spring(duration: 0.4, bounce: 0.3).delay(0.22)) { swells = false }
        }
        AccessibilityNotification.Announcement("\(PlanMessages.stepFinished): \(step.title)").post()
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard finished?.id == step.id else { return }
            withAnimation(animation) { finished = nil }
        }
    }
}

/// The chats in the plan, to go back to one, or to start another; in the bar and in the island.
struct PlanChatsMenu: View {
    let conversations: [PavePlanConversation]
    let currentConversationID: String?
    let onOpen: (String) -> Void
    let onNew: () -> Void

    var body: some View {
        let others = conversations.filter { $0.id != currentConversationID }
        Menu {
            Button(PlanMessages.newConversation, systemImage: "square.and.pencil", action: onNew)
            if !others.isEmpty {
                Section(PlanMessages.conversations) {
                    ForEach(Array(others.enumerated()), id: \.element.id) { index, chat in
                        Button(chat.title.isEmpty ? PlanMessages.untitledConversation(index + 1) : chat.title) {
                            onOpen(chat.id)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(.iconChat)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(13)
                Text(PlanMessages.conversationCount(conversations.count))
                    .textStyle(.tag)
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Color.paveSurfaceTint, in: .capsule)
        }
        .accessibilityLabel("\(PlanMessages.conversations), \(PlanMessages.conversationCount(conversations.count))")
    }
}

#Preview {
    @Previewable @State var isExpanded = false
    @Previewable @State var plan = PavePlan(template: PlanTemplates.job)
    VStack(spacing: 16) {
        PlanDynamicBar(
            plan: plan, conversations: [PavePlanConversation(id: "1", title: "Wat voor werk zoek ik?")], currentConversationID: nil,
            isExpanded: $isExpanded, onOpenPlan: {}, onCompleteStep: { plan.completeCurrentStep() },
            onOpenConversation: { _ in }, onNewConversation: {}
        )
        .padding(.horizontal, 16)
        Spacer()
    }
    .background(Color.canvas)
}
