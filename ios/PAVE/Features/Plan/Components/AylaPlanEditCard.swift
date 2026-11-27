import PAVECore
import SwiftUI

/// Under Ayla's answer when she proposes changes to the plan so it reaches its goal: new steps, steps that can go,
/// steps in another order, each with why. Untick what you do not want; nothing changes before "Pas plan aan".
struct AylaPlanEditCard: View {
    let edit: AylaReply.PlanEdit
    let plan: PavePlan
    let decision: PlanModel.EditDecision?
    let onApply: ([AylaReply.PlanEdit.Change]) -> Void
    let onDecline: () -> Void
    let onOpenPlan: () -> Void

    @State private var unticked: Set<Int> = []

    private var chosen: [AylaReply.PlanEdit.Change] {
        edit.changes.indices.filter { !unticked.contains($0) }.map { edit.changes[$0] }
    }

    var body: some View {
        switch decision {
        case .applied: done
        case .declined: EmptyView()
        case nil: question
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                PaveMark()
                VStack(alignment: .leading, spacing: 1) {
                    Text(PlanMessages.editTitle)
                        .textStyle(.label)
                        .foregroundStyle(Color.ink)
                    Text(plan.name)
                        .textStyle(.meta)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(edit.changes.indices, id: \.self) { index in
                    line(index)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
            HStack(spacing: 8) {
                Button {
                    PaveHaptics.tap(.light)
                    onDecline()
                } label: {
                    Text(PlanMessages.notYet)
                        .textStyle(.label)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.railBorder, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.pave)
                Button {
                    PaveHaptics.tap(.medium)
                    onApply(chosen)
                } label: {
                    Text(PlanMessages.editApply)
                        .textStyle(.label)
                        .foregroundStyle(chosen.isEmpty ? Color.inkMuted : .white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(chosen.isEmpty ? Color.controlDisabled : .paveAccentFill, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.pave)
                .disabled(chosen.isEmpty)
            }
        }
        .padding(16)
        .frame(maxWidth: 340, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private func label(for change: AylaReply.PlanEdit.Change) -> String {
        switch change.op {
        case .add: PlanMessages.editAdd
        case .remove: PlanMessages.editRemove
        case .move: PlanMessages.editMove
        }
    }

    /// Where a new or moved step lands, by the step before it.
    private func place(of change: AylaReply.PlanEdit.Change) -> String? {
        guard change.op != .remove else { return nil }
        guard let after = change.afterStepId else { return PlanMessages.editAtStart }
        return plan.steps.first { $0.id == after }.map { PlanMessages.editAfter($0.title) }
    }

    private func line(_ index: Int) -> some View {
        let change = edit.changes[index]
        let isOn = !unticked.contains(index)
        let goes = change.op == .remove && isOn
        return Button {
            PaveHaptics.selection()
            if isOn { unticked.insert(index) } else { unticked.remove(index) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                PaveCheckbox(isOn: isOn)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text([label(for: change), place(of: change)].compactMap { $0 }.joined(separator: " · "))
                        .textStyle(.meta)
                        .foregroundStyle(change.op == .remove ? Color.criticalInk : .paveAccent)
                    Text(change.title)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(goes ? Color.inkMuted : .ink)
                        .strikethrough(goes, color: .inkMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !change.why.isEmpty {
                        Text(change.why)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var done: some View {
        Button(action: onOpenPlan) {
            HStack(spacing: 6) {
                Image(.iconCheckCircle)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(14)
                    .accessibilityHidden(true)
                Text(PlanMessages.editDone)
                Text("·").accessibilityHidden(true)
                Text(PlanMessages.openPlan)
                    .underline()
            }
            .textStyle(.caption)
            .foregroundStyle(Color.paveAccent)
            .padding(.leading, 4)
        }
        .buttonStyle(.pave)
    }
}

#Preview {
    let plan = PavePlan(name: "Piloot worden", steps: [
        PavePlanStep(id: "a", title: "Opleidingen vergelijken"),
        PavePlanStep(id: "b", title: "Cursus Engels"),
    ])
    AylaPlanEditCard(
        edit: .init(id: "e", planId: plan.id, changes: [
            .init(op: .add, title: "Medische keuring aanvragen", kind: "action", afterStepId: "a", why: "Zonder klasse 1-keuring kun je niet beginnen."),
            .init(op: .remove, stepId: "b", title: "Cursus Engels", why: "Je B2-certificaat staat al in je kluis."),
        ]),
        plan: plan, decision: nil, onApply: { _ in }, onDecline: {}, onOpenPlan: {}
    )
    .padding()
}
