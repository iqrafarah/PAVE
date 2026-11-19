import SwiftUI

/// While you talk with Ayla and a page is open over her orb: a glow along the edge of the page shows she is still
/// there. It follows your voice while she listens, breathes while she thinks and follows her voice while she speaks.
struct AylaVoiceEdgeGlow: View {
    let mode: AylaPixelOrb.Mode
    let meter: VoiceMeter
    var cornerRadius: CGFloat = 25

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: mode == .idle)) { context in
            let strength = strength(at: context.date)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            ZStack {
                shape.strokeBorder(Color.paveAccent, lineWidth: 6 + 14 * strength)
                    .blur(radius: 10 + 8 * strength)
                    .opacity(0.25 + 0.55 * strength)
                shape.strokeBorder(Color.paveAccent, lineWidth: 2)
                    .opacity(0.35 + 0.5 * strength)
            }
        }
        .opacity(mode == .idle ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: mode)
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .sensoryFeedback(trigger: mode) { _, new in
            switch new {
            case .listening: .impact(weight: .light)
            case .speaking: .impact(weight: .medium, intensity: 0.6)
            default: nil
            }
        }
    }

    private func strength(at date: Date) -> Double {
        let time = date.timeIntervalSinceReferenceDate
        switch mode {
        case .listening: return reduceMotion ? 0.4 : min(1, Double(meter.microphoneLevel) * 1.6)
        case .speaking: return reduceMotion ? 0.6 : 0.25 + min(0.75, Double(meter.speakerLevel) * 1.4)
        case .thinking: return reduceMotion ? 0.3 : 0.3 + 0.25 * sin(time * 2.6)
        default: return 0
        }
    }
}
