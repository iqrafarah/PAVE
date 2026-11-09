import SwiftUI
import WidgetKit

/// The small widget is one button (talk with Ayla); the medium one also starts a new chat. In the style of the
/// splash screen: the light canvas with green in the corners and the pixel slash.
/// With a clear or tinted Home Screen iOS draws everything in one colour and keeps only how see-through it is, so
/// the buttons become light glass with the text and icons fully on top, instead of solid shapes they would vanish in.
struct AylaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var isFullColor: Bool { renderingMode == .fullColor }

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            HStack(alignment: .bottom, spacing: 16) {
                title
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    Link(destination: PaveLink.talk.url) {
                        AylaWidgetButton(title: "Praat met Ayla", isPrimary: true, isFullColor: isFullColor) {
                            PixelWaveIcon(color: isFullColor ? .white : .primary)
                        }
                    }
                    Link(destination: PaveLink.newConversation.url) {
                        AylaWidgetButton(title: "Nieuw gesprek", isPrimary: false, isFullColor: isFullColor) {
                            Image(.iconCompose).renderingMode(.template)
                        }
                    }
                }
                .frame(width: 164)
            }
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                PixelWaveIcon(color: .primary)
                    .scaleEffect(1.3)
            }
            .widgetURL(PaveLink.talk.url)
            .accessibilityLabel("Praat met Ayla")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                PaveMark(size: 5, color: .primary)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 0) {
                    Text("Ayla")
                        .font(.custom("Sora-Regular_SemiBold", size: 16))
                    Text("Praat met Ayla")
                        .font(.custom("InterVariable-Medium", size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .widgetURL(PaveLink.talk.url)
        default:
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    PaveMark(size: 5.5)
                        .widgetAccentable()
                    Spacer(minLength: 0)
                    PixelWaveIcon(color: isFullColor ? .white : .primary)
                        .scaleEffect(1.25)
                        .frame(width: 44, height: 44)
                        .background(isFullColor ? Color.brandGreen : Color.primary.opacity(0.18), in: .circle)
                        .widgetAccentable()
                }
                Spacer(minLength: 0)
                Text("Ayla")
                    .font(.custom("Sora-Regular_SemiBold", size: 24))
                    .foregroundStyle(isFullColor ? Color.ink : .primary)
                Text("Praat met Ayla")
                    .font(.custom("InterVariable-Medium", size: 13))
                    .foregroundStyle(isFullColor ? Color.inkMuted : .secondary)
            }
            .widgetURL(PaveLink.talk.url)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Praat met Ayla")
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            PaveMark(size: 5.5)
                .widgetAccentable()
            Spacer(minLength: 0)
            Text("Ayla")
                .font(.custom("Sora-Regular_SemiBold", size: 24))
                .foregroundStyle(isFullColor ? Color.ink : .primary)
            Text("Je gids in PAVE")
                .font(.custom("InterVariable-Medium", size: 13))
                .foregroundStyle(isFullColor ? Color.inkMuted : .secondary)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular:
            Color.clear
        default:
            ZStack {
                Color.canvas
                LinearGradient(
                    stops: [
                        .init(color: .brandGreen.opacity(0.22), location: 0),
                        .init(color: .canvas.opacity(0), location: 0.45),
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
        }
    }
}

/// A capsule in the widget: green to talk, white for a new chat. On a clear or tinted Home Screen both are light
/// glass, the one to talk a little stronger, with the text and icon on top.
struct AylaWidgetButton<Icon: View>: View {
    let title: String
    let isPrimary: Bool
    var isFullColor = true
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(spacing: 8) {
            icon
                .frame(width: 18, height: 18)
            Text(title)
                .font(.custom("InterVariable-SemiBold", size: 14))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(foreground)
        .widgetAccentable(isPrimary)
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 12)
        .background(background, in: .capsule)
    }

    private var foreground: Color {
        guard isFullColor else { return .primary }
        return isPrimary ? .white : .ink
    }

    private var background: Color {
        guard isFullColor else { return Color.primary.opacity(isPrimary ? 0.22 : 0.12) }
        return isPrimary ? .brandGreen : .white
    }
}
