import ActivityKit
import SwiftUI
import WidgetKit

/// The spoken conversation with Ayla on the Lock Screen and in the Dynamic Island: what she is doing, and how to go
/// on without looking. Only her status, never what is said.
struct AylaVoiceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AylaVoiceActivityAttributes.self) { context in
            HStack(spacing: 14) {
                badge(context.state.status, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(.headline)
                    Text(context.state.hint)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .activityBackgroundTint(Color.white.opacity(0.9))
            .activitySystemActionForegroundColor(Color.brandGreen)
            .widgetURL(PaveLink.talk.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    badge(context.state.status, size: 36)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.hint)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                PixelWaveIcon(color: Color.brandGreen)
            } compactTrailing: {
                Text(context.state.short)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandGreen)
            } minimal: {
                PixelWaveIcon(color: Color.brandGreen)
            }
            .widgetURL(PaveLink.talk.url)
        }
    }

    private func badge(_ status: AylaVoiceActivityAttributes.ContentState.Status, size: CGFloat) -> some View {
        PixelWaveIcon(color: .white)
            .frame(width: size, height: size)
            .background(status == .muted || status == .paused ? Color.gray : Color.brandGreen, in: .circle)
    }
}
