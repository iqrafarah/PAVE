import PAVECore
import SwiftUI

extension EnvironmentValues {
    /// The plan of the chat shows around the iPhone's Dynamic Island instead of as a pill under Ayla's header.
    @Entry var plansInIsland = false
}

/// The chat says the plan should step aside, such as while you talk with Ayla.
struct PlanIslandHiddenKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

/// Where the iPhone's Dynamic Island is, from the height of the top safe area: only iPhones with one have 54 points or
/// more there. Nil on other iPhones, on iPad and sideways, where the pill under the header is used.
enum DynamicIslandFrame {
    static func frame(topInset: CGFloat, width: CGFloat) -> CGRect? {
        guard UIDevice.current.userInterfaceIdiom == .phone, topInset >= 54, width < 500 else { return nil }
        let size = CGSize(width: 125, height: 37)
        let top: CGFloat = topInset >= 62 ? 14 : 11
        return CGRect(x: (width - size.width) / 2, y: top, width: size.width, height: size.height)
    }

    /// The closed iPhone Duo: no status bar on top but a column on the right, with the camera at the top of it (measured
    /// on Daaf's Duo: a capsule of 37 × 63 pt, its centre 6 pt left of the column's middle and 57 pt from the top; the
    /// Simulator draws a round one elsewhere). `width` is the width beside the column. Nil on every other screen.
    static func sideFrame(topInset: CGFloat, trailingInset: CGFloat, width: CGFloat) -> CGRect? {
        guard UIDevice.current.userInterfaceIdiom == .phone, topInset < 20, trailingInset >= 60, width < 500 else { return nil }
        let size = CGSize(width: 37, height: 63)
        let center = CGPoint(x: width + trailingInset / 2 - 6, y: 57)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }
}

/// The plan of the open chat, grown out of the iPhone's own Dynamic Island, as the system does with a Live Activity
/// (which iOS does not show while PAVE itself is open). Compact it sits around the camera: the ring on the left, how
/// far you are on the right. When a plan comes in view or a step is finished it opens for a moment with the plan and
/// the step; a tap opens it all the way, with every step, the chats and "Open plan".
struct PlanIsland: View {
    let plan: PavePlan
    let conversations: [PavePlanConversation]
    let currentConversationID: String?
    /// The hardware island, in the coordinates of the screen.
    let island: CGRect
    let screenWidth: CGFloat
    /// The camera sits in a column on the right (closed iPhone Duo): the island grows out of it to the left.
    var isSide = false
    @Binding var isExpanded: Bool
    let onOpenPlan: () -> Void
    let onCompleteStep: () -> Void
    let onOpenConversation: (String) -> Void
    let onNewConversation: () -> Void

    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var notice: Notice?
    @State private var stepsHeight: CGFloat = 0

    /// How far the compact island reaches out on each side of the camera: as a Live Activity of the system, so the
    /// clock and the signal icons stay free.
    static let side: CGFloat = 30
    /// How far the side island reaches out of the column to the left of the camera, for the ring and how far you are.
    static let sideReach: CGFloat = 78
    /// iOS keeps every touch in the status bar for itself (it scrolls to the top), and around the camera there is no
    /// screen at all. So an invisible strip just below the island, under the status bar, counts as touching it.
    static let reach: CGFloat = 30
    static let reachSide: CGFloat = 16

    /// What the island says for a moment.
    private enum Notice: Equatable {
        case plan
        case finished(PavePlanStep)
    }

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.28)
    }

    /// Where it grows from: the middle of the top, or the camera in the column on the right.
    private var anchor: UnitPoint { isSide ? .topTrailing : .top }

    /// From the right edge of the screen to the right side of the camera, for the side island.
    private var trailingRoom: CGFloat { max(0, screenWidth - island.maxX) }

    /// How far the side island tucks in behind the camera: to its middle. Black all the way under the camera made iOS
    /// draw a grey shade around it in the column.
    private var sideTuck: CGFloat { island.width / 2 }

    var body: some View {
        ZStack(alignment: isSide ? .topTrailing : .top) {
            if isExpanded {
                card
                    // Under the camera at the top; beside it, out of the column to the left, on the closed Duo.
                    .padding(.top, isSide ? island.minY : island.maxY + 8)
                    .padding(.trailing, isSide ? screenWidth - island.minX + 6 : 0)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.4, anchor: anchor).combined(with: .opacity),
                        removal: .scale(scale: 0.6, anchor: anchor).combined(with: .opacity)
                    ))
            } else {
                blackIsland
                    .padding(.top, island.minY)
                    .padding(.trailing, isSide ? trailingRoom + island.width - sideTuck - Self.reachSide : 0)
                    .transition(.scale(scale: 0.85, anchor: anchor).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: isSide ? .topTrailing : .top)
        .animation(animation, value: isExpanded)
        .animation(animation, value: notice)
        .animation(.easeOut(duration: 0.25), value: plan)
        .sensoryFeedback(.success, trigger: plan.doneCount) { old, new in new > old }
        .task(id: plan.id) { await show(.plan) }
        .onChange(of: plan.doneCount) { old, new in
            guard new > old, let step = lastFinished else { return }
            Task { await show(.finished(step)) }
        }
    }

    // MARK: The island, black as the camera

    private var blackIsland: some View {
        // On the Duo a slim capsule from the top of the camera, as high as the camera is wide, so the two black shapes
        // run into each other.
        let height = isSide ? island.width : island.height
        let radius: CGFloat = notice == nil ? height / 2 : 34
        let compactWidth = isSide ? sideTuck + Self.sideReach : island.width + 2 * Self.side
        let noticeWidth = isSide ? min(island.minX + sideTuck - 12, 380) : screenWidth - 24
        return Group {
            if notice == nil {
                compact
            } else {
                noticeContent
            }
        }
        .frame(width: notice == nil ? compactWidth : noticeWidth)
        .background(Color.black, in: .rect(cornerRadius: radius, style: .continuous))
        // Dark inside, as the system island: PAVE's colours turn light on black.
        .environment(\.colorScheme, .dark)
        // The touchable strip below and beside it: nothing shows there.
        .padding(.bottom, notice == nil ? Self.reach : 0)
        .padding(.horizontal, Self.reachSide)
        .contentShape(.rect)
        .onTapGesture(perform: toggle)
        .onLongPressGesture(minimumDuration: 0.45) {
            PaveHaptics.tap(.medium)
            onOpenPlan()
        }
        // Pulled down, or out of the column to the left, it opens.
        .simultaneousGesture(
            DragGesture(minimumDistance: 8).onEnded { drag in
                if drag.translation.height > 12 || isSide && drag.translation.width < -12 { toggle() }
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(PlanMessages.islandHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: PlanMessages.openPlan) { onOpenPlan() }
    }

    // MARK: Open: a card in PAVE's own glass, just under the island

    private var card: some View {
        expanded
            .frame(width: isSide ? min(island.minX - 14, 560) : min(screenWidth - 16, 560))
            .glassEffect(.regular.tint(Color.panel.opacity(0.97)), in: .rect(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
            // Pushed up, it folds again.
            .simultaneousGesture(
                DragGesture(minimumDistance: 12).onEnded { drag in
                    if drag.translation.height < -24 { toggle() }
                }
            )
    }

    private func toggle() {
        PaveHaptics.tap(.light)
        withAnimation(animation) {
            notice = nil
            isExpanded.toggle()
        }
    }

    /// A moment open, then back around the camera, unless it was opened all the way meanwhile.
    private func show(_ next: Notice) async {
        // One message at the top at a time: with a melding or Ayla's answer there, the island stays around the camera.
        guard !isExpanded, !PaveTopSlot.shared.isTaken else { return }
        withAnimation(animation) { notice = next }
        try? await Task.sleep(for: .seconds(next == .plan ? 2.6 : 2.2))
        guard notice == next else { return }
        withAnimation(animation) { notice = nil }
    }

    // MARK: Around the camera

    private var compact: some View {
        Group {
            if isSide {
                // Left of the camera, which is the right end of the capsule.
                HStack(spacing: 8) {
                    PlanProgressRing(plan: plan, size: 18)
                    Text(plan.isFinished ? "✓" : PlanMessages.shortProgress(plan))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.paveAccent)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: sideTuck + 4)
                }
                .padding(.leading, 12)
                .frame(height: island.width)
            } else {
                topCompact
            }
        }
    }

    private var topCompact: some View {
        VStack(spacing: 0) {
            // Beside the camera: how far, as the system shows a Live Activity.
            HStack(spacing: 0) {
                PlanProgressRing(plan: plan, size: 18)
                Spacer(minLength: island.width)
                Text(plan.isFinished ? "✓" : PlanMessages.shortProgress(plan))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.paveAccent)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.leading, 7)
            .padding(.trailing, 8)
            .frame(height: island.height)
        }
    }

    // MARK: For a moment

    private var noticeContent: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                switch notice {
                case .finished(let step):
                    PlanStepMark(status: .done, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(PlanMessages.stepFinished)
                            .textStyle(.caption)
                            .foregroundStyle(Color.paveAccent)
                        Text(step.title)
                            .textStyle(.chip)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                default:
                    PlanProgressRing(plan: plan, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(plan.name)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                        Text(plan.currentStep?.title ?? (plan.isFinished ? PlanMessages.finished : PlanMessages.noSteps))
                            .textStyle(.chip)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if plan.totalCount > 0 {
                    Text(PlanMessages.shortProgress(plan))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.paveAccent)
                }
            }
            // How to go on: pull it down, as the system island.
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 4)
        }
        .padding(.leading, 18)
        // Clear of the camera: below it at the top, left of it in the column.
        .padding(.trailing, isSide ? sideTuck + 12 : 18)
        .padding(.top, isSide ? 10 : island.height + 6)
        .padding(.bottom, 10)
    }

    // MARK: All the way open

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: toggle) {
                HStack(spacing: 12) {
                    PlanProgressRing(plan: plan, size: 34)
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
            .buttonStyle(.plain)
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
                                Button(action: onCompleteStep) { Text(PlanMessages.markDone) }
                                    .textStyle(.tag)
                                    .foregroundStyle(Color.paveAccent)
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 28)
                                    .background(Color.paveSurfaceTint, in: .capsule)
                                    // Small to look at, a full finger to hit.
                                    .padding(.vertical, 8)
                                    .contentShape(.rect)
                                    .padding(.vertical, -8)
                                    .buttonStyle(.pave)
                            }
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { stepsHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(max(stepsHeight, 20), 300))

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
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

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

    private var lastFinished: PavePlanStep? {
        plan.steps.filter { $0.status == .done }.max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }
}

/// The island over the whole Ayla page, above its header, so unfolding it never slides under the buttons. A tap next to
/// the unfolded island folds it again.
struct PlanIslandOverlay: View {
    let chat: AylaChatModel
    let island: CGRect
    let screenWidth: CGFloat
    var isSide = false

    @Environment(PlanModel.self) private var plans: PlanModel?
    @Environment(\.openPlan) private var openPlan
    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    private var plan: PavePlan? {
        plans?.activePlan(conversationID: chat.conversationID, newChatPlanID: chat.newChatPlan?.planID)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if isExpanded {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { setExpanded(false) }
                    .accessibilityHidden(true)
            }
            if let plan {
                PlanIsland(
                    plan: plan,
                    conversations: plan.liveConversations(in: chat.conversationList, isComplete: chat.hasLoadedList && !chat.canLoadMore && !chat.listFailed),
                    currentConversationID: chat.conversationID,
                    island: island,
                    screenWidth: screenWidth,
                    isSide: isSide,
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
                        chat.newConversation(in: chat.conversationList.projects.first { $0.id == plan.projectID }, plan: plan.id, step: plan.currentStep?.id)
                    }
                )
                .transition(.scale(scale: 0.6, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.2), value: plan?.id)
        .onChange(of: chat.conversationID) { setExpanded(false) }
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.28)) { isExpanded = value }
    }
}

#Preview {
    @Previewable @State var isExpanded = false
    @Previewable @State var plan = PavePlan(template: PlanTemplates.job)
    ZStack(alignment: .top) {
        Color.canvas.ignoresSafeArea()
        PlanIsland(
            plan: plan, conversations: [], currentConversationID: nil,
            island: CGRect(x: 134, y: 11, width: 125, height: 37), screenWidth: 393, isExpanded: $isExpanded,
            onOpenPlan: {}, onCompleteStep: { plan.completeCurrentStep() }, onOpenConversation: { _ in }, onNewConversation: {}
        )
        .ignoresSafeArea()
    }
}
