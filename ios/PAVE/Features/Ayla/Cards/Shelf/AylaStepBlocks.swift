import SwiftUI

/// Ayla's pixel blocks as progress: one block per step, filled when it is done, breathing while she is on it, red when
/// it did not work. The same blocks she thinks with, so it reads as her and not as a loading bar.
struct AylaStepBlocks: View {
    let steps: [AylaActionStep]

    @Environment(\.paveAnimationsOff) private var animationsOff
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            ForEach(steps) { step in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(step.state == .failed ? Color.criticalInk : Color.paveAccent)
                    .frame(width: 7, height: 7)
                    .opacity(step.state == .waiting ? 0.22 : 1)
                    .modifier(Breathing(isOn: step.state == .running && !animationsOff && !reduceMotion))
            }
        }
        .accessibilityHidden(true)
    }
}

/// A slow fade in and out for the block of the step she is on.
private struct Breathing: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.phaseAnimator([1.0, 0.35]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in .easeInOut(duration: 0.6) }
        } else {
            content
        }
    }
}
