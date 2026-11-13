import SwiftUI

extension View {
    /// A soft band of light that sweeps across grey shapes while something loads. With Reduce Motion it only breathes.
    func paveShimmer(isActive: Bool = true) -> some View {
        modifier(PaveShimmer(isActive: isActive))
    }
}

private struct PaveShimmer: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if !isActive {
            content
        } else if reduceMotion {
            content.phaseAnimator([1, 0.6]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in .easeInOut(duration: 1.1) }
        } else {
            content.overlay {
                TimelineView(.animation) { timeline in
                    let progress = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.7), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                            .frame(width: width * 0.45)
                            .offset(x: -width * 0.45 + (width * 1.45) * progress)
                    }
                }
                .mask(content)
                .allowsHitTesting(false)
            }
        }
    }
}
