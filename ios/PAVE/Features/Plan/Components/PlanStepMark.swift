import PAVECore
import SwiftUI

/// The mark of a step: a filled check when it is done, an orange ring with a dot for the step you are on, an empty
/// ring for what is still to come and a dash for a skipped step.
struct PlanStepMark: View {
    let status: PavePlanStep.Status
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            switch status {
            case .upcoming:
                Circle().strokeBorder(Color.inkMuted.opacity(0.45), lineWidth: 1.5)
            case .active:
                Circle().strokeBorder(Color.paveAccent, lineWidth: 2)
                Circle()
                    .fill(Color.paveAccent)
                    .padding(size * 0.27)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            case .done:
                Image(.iconCheck)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.25)
                    .foregroundStyle(Color.white)
                    .background(Color.paveAccentFill, in: .circle)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            case .skipped:
                Circle().strokeBorder(Color.inkMuted.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
                Capsule()
                    .fill(Color.inkMuted.opacity(0.6))
                    .frame(width: size * 0.4, height: 1.5)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(duration: 0.3, bounce: 0.3), value: status)
        .accessibilityHidden(true)
    }
}

/// How far a plan is, as a thin ring around the icon of the step you are on. Skipped steps do not count.
struct PlanProgressRing: View {
    let plan: PavePlan
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.paveSurfaceTint, lineWidth: 3)
            Circle()
                .trim(from: 0, to: plan.progress)
                .stroke(Color.paveAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Group {
                if plan.isFinished {
                    Image(.iconCheck)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.36)
                        .foregroundStyle(Color.paveAccent)
                } else if let step = plan.currentStep {
                    // What kind of step you are on; how far you are is the ring itself.
                    Image(step.kind.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.4, height: size * 0.4)
                        .foregroundStyle(Color.ink)
                        .id(step.id)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(duration: 0.5, bounce: 0.1), value: plan.progress)
        .accessibilityHidden(true)
    }
}

/// How far a plan is, as a bar.
struct PlanProgressBar: View {
    let progress: Double

    var body: some View {
        Capsule()
            .fill(Color.paveSurfaceTint)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.paveAccentFill)
                        .frame(width: max(progress > 0 ? 6 : 0, proxy.size.width * progress))
                }
            }
            .frame(height: 6)
            .animation(.spring(duration: 0.5, bounce: 0.1), value: progress)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(PavePlanStep.Status.allCases, id: \.self) { PlanStepMark(status: $0) }
        PlanProgressRing(plan: PavePlan(template: PlanTemplates.job))
    }
    .padding()
    .background(Color.canvas)
}
