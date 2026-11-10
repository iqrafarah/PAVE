import SwiftUI

/// Draws what follows Ayla's orb (the orb itself, the field around it) at the orb's frame on screen, with how far
/// it is stretched towards the finger. Only this view reads the orb's movement, so while the orb moves nothing
/// else in the chat screen has to be redrawn.
/// The two places animate when they move (the keyboard, turning the device), so the orb glides along.
struct AylaOrbTrack<Content: View>: View, Animatable {
    let motion: AylaOrbMotion
    var stage: CGRect
    var bar: CGRect
    @ViewBuilder let content: (CGRect, CGSize) -> Content

    var animatableData: AnimatablePair<CGRect.AnimatableData, CGRect.AnimatableData> {
        get { AnimatablePair(stage.animatableData, bar.animatableData) }
        set {
            stage.animatableData = newValue.first
            bar.animatableData = newValue.second
        }
    }

    var body: some View {
        content(Self.frame(of: motion, stage: stage, bar: bar), Self.scale(for: motion.stretch))
    }

    /// The orb's frame on screen: large in the middle, small above the voice bar, moved by the elastic.
    static func frame(of motion: AylaOrbMotion, stage: CGRect, bar: CGRect) -> CGRect {
        if stage.isEmpty { return bar }
        if bar.isEmpty { return stage }
        func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
        let side = max(1, mix(stage.width, bar.width, motion.size))
        let x = mix(stage.midX, bar.midX, motion.position)
        let y = mix(stage.midY, bar.midY, motion.position) + motion.pull
        return CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side)
    }

    /// Stretched towards the finger, as measured in ChatGPT: much longer and a little wider.
    static func scale(for stretch: CGFloat) -> CGSize {
        CGSize(width: 1 + stretch * 0.08, height: 1 + stretch * 0.42)
    }
}
