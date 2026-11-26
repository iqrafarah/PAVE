import ActivityKit
import SwiftUI
import WidgetKit

/// The plan you follow, on the Lock Screen and in the Dynamic Island: a ring for how far you are and one line about
/// the step. Never the timeline: details are in the app. The Lock Screen keeps the system's own background and text
/// colours; only the ring has the theme colour. A tap opens the plan in PAVE, after the PIN or Face ID.
struct PlanLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlanActivityAttributes.self) { context in
            PlanLockScreenView(state: context.state, accent: context.attributes.accent)
                .widgetURL(PaveLink.plan.url)
        } dynamicIsland: { context in
            let accent = context.attributes.accent
            let light = accent.mix(with: .white, by: 0.35)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PlanRing(state: context.state, accent: light, size: 40, lineWidth: 4)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.short)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(light)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(context.state.line)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                PlanRing(state: context.state, accent: light, size: 18, lineWidth: 2.5)
            } compactTrailing: {
                Text(context.state.short)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(light)
            } minimal: {
                PlanRing(state: context.state, accent: light, size: 18, lineWidth: 2.5)
            }
            .widgetURL(PaveLink.plan.url)
            .keylineTint(accent)
        }
    }
}

private struct PlanLockScreenView: View {
    let state: PlanActivityAttributes.ContentState
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            PlanRing(state: state, accent: accent, size: 44, lineWidth: 4.5)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(state.line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(state.short)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

/// How far the plan is, as a ring around the symbol of the step you are on (a check when it is done).
private struct PlanRing: View {
    let state: PlanActivityAttributes.ContentState
    let accent: Color
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: state.progress)
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: state.isFinished ? "checkmark" : state.symbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(state.doneCount) van \(state.totalCount) stappen afgerond")
    }
}

#Preview("Toegangsscherm", as: .content, using: PlanActivityAttributes(planID: "p")) {
    PlanLiveActivity()
} contentStates: {
    PlanActivityAttributes.ContentState(stepNumber: 3, totalCount: 6, doneCount: 2, isFinished: false, kindTitle: "Bewijs in je kluis", symbol: "folder")
    PlanActivityAttributes.ContentState(stepNumber: 3, totalCount: 6, doneCount: 2, isFinished: false, symbol: "folder", planName: "Een baan vinden", stepTitle: "Bewijs in je kluis")
}
