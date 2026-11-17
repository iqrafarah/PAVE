import ActivityKit
import SwiftUI
import WidgetKit

/// The spoken conversation with Ayla on the Lock Screen and in the Dynamic Island: what she is doing, and how to go
/// on without looking. Only her status, never what is said. The Lock Screen keeps the system's own background and
/// text colours, so it reads in light and dark and with a tinted Lock Screen; only the round badge has the theme colour.
struct AylaVoiceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AylaVoiceActivityAttributes.self) { context in
            AylaVoiceLockScreenView(status: context.state, accent: context.attributes.accent)
                .widgetURL(PaveLink.talk.url)
        } dynamicIsland: { context in
            let accent = context.attributes.accent
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AylaVoiceBadge(status: context.state.status, accent: accent, size: 40)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.hint)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
            } compactLeading: {
                PixelWaveIcon(color: accent.mix(with: .white, by: 0.35))
            } compactTrailing: {
                Text(context.state.short)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent.mix(with: .white, by: 0.35))
            } minimal: {
                PixelWaveIcon(color: accent.mix(with: .white, by: 0.35))
            }
            .widgetURL(PaveLink.talk.url)
            .keylineTint(accent)
        }
    }
}

private struct AylaVoiceLockScreenView: View {
    let status: AylaVoiceActivityAttributes.ContentState
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            AylaVoiceBadge(status: status.status, accent: accent, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(status.hint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

/// The theme colour with the pixel wave; grey while Ayla is paused or the microphone is off. In a tinted or
/// always-on Lock Screen iOS draws it in one colour, so it stays a clear shape.
private struct AylaVoiceBadge: View {
    let status: AylaVoiceActivityAttributes.ContentState.Status
    let accent: Color
    let size: CGFloat

    var body: some View {
        PixelWaveIcon(color: .white)
            .frame(width: size, height: size)
            .background(status == .muted || status == .paused ? Color.gray : accent, in: .circle)
            .accessibilityHidden(true)
    }
}
