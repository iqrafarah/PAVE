import PAVECore
import SwiftUI

/// The steps of a plan from top to bottom, joined by a line that is orange as far as you have come. Used in the
/// Dynamic Bar and on the page of a plan. `onSelect` makes a step tappable; `trailing` puts something next to a step,
/// such as a button to finish the one you are on.
struct PlanTimeline<Trailing: View>: View {
    let steps: [PavePlanStep]
    var showsSummary = true
    var spacing: CGFloat = 14
    var onSelect: ((PavePlanStep) -> Void)?
    @ViewBuilder var trailing: (PavePlanStep) -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                row(step, isLast: index == steps.count - 1)
            }
        }
    }

    @ViewBuilder
    private func row(_ step: PavePlanStep, isLast: Bool) -> some View {
        let content = HStack(alignment: .top, spacing: 12) {
            PlanStepMark(status: step.status)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .textStyle(step.status == .active ? .label : .chip)
                    .foregroundStyle(step.status == .upcoming || step.status == .skipped ? Color.inkMuted : Color.ink)
                    .strikethrough(step.status == .skipped, color: Color.inkMuted)
                    .multilineTextAlignment(.leading)
                if showsSummary, !step.summary.isEmpty {
                    Text(step.summary)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if let extra = PlanMessages.stepExtras(step) {
                    Text(extra)
                        .textStyle(.caption)
                        .foregroundStyle(PlanMessages.isOverdue(step) ? Color.critical : Color.inkMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing(step)
        }
        .padding(.bottom, isLast ? 0 : spacing)
        .background(alignment: .topLeading) {
            if !isLast {
                // The line to the next step: orange once this step is done.
                Rectangle()
                    .fill(step.status == .done ? Color.paveAccent.opacity(0.6) : Color.inkMuted.opacity(0.22))
                    .frame(width: 2)
                    .padding(.top, 24)
                    .padding(.bottom, 3)
                    .padding(.leading, 9)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        // What the row combines would swallow its buttons, such as Klaar: they stay reachable as actions.
        .accessibilityActions { trailing(step) }
        .accessibilityLabel("\(step.title), \(PlanMessages.status(step.status))\(step.summary.isEmpty ? "" : ". \(step.summary)")\(PlanMessages.stepExtras(step).map { ". \($0)" } ?? "")")

        if let onSelect {
            Button { onSelect(step) } label: { content }
                .buttonStyle(.pave)
        } else {
            content
        }
    }
}

extension PlanTimeline where Trailing == EmptyView {
    init(steps: [PavePlanStep], showsSummary: Bool = true, spacing: CGFloat = 14, onSelect: ((PavePlanStep) -> Void)? = nil) {
        self.init(steps: steps, showsSummary: showsSummary, spacing: spacing, onSelect: onSelect) { _ in EmptyView() }
    }
}

#Preview {
    PlanTimeline(steps: PavePlan(template: PlanTemplates.job).steps)
        .padding()
        .background(Color.canvas)
}
