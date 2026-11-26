import SwiftUI

/// "Klaar met deze stap?": what you just did fits the step a plan is on. One tap finishes it; nothing happens without it.
struct PlanStepSuggestionCard: View {
    let suggestion: PlanModel.StepSuggestion
    /// As a banner over the app it says which plan; on the plan's own page it does not need to.
    var showsPlan = true
    let onFinish: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                Image(.iconMapSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(18)
                    .foregroundStyle(Color.paveAccent)
                    .frame(width: 36, height: 36)
                    .background(Color.paveAccent.opacity(0.14), in: .rect(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(PlanMessages.suggestionTitle)
                        .textStyle(.caption)
                        .foregroundStyle(Color.paveAccent)
                    Text(suggestion.stepTitle)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                    if showsPlan {
                        Text(PlanMessages.fromPlan(suggestion.planName))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text(PlanMessages.notYet)
                        .textStyle(.chip)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.railBorder, in: .capsule)
                        .contentShape(.capsule)
                }
                Button(action: onFinish) {
                    Text(PlanMessages.markDone)
                        .textStyle(.chip)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.paveAccentFill, in: .capsule)
                        .contentShape(.capsule)
                }
            }
            .buttonStyle(.pave)
        }
        .padding(12)
        .frame(maxWidth: 420)
        .background(Color.panel, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder) }
    }
}

#Preview {
    PlanStepSuggestionCard(
        suggestion: .init(planID: "p", stepID: "s", planName: "Scrum-certificaat halen", stepTitle: "Zet je certificaat in je kluis", evidenceID: nil),
        onFinish: {}, onDismiss: {}
    )
    .padding()
}
