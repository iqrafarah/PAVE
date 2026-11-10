import SwiftUI

/// Shakes the pin pad and plays an error haptic each time `trigger` changes, like the iPhone's own passcode screen.
/// Without the shake when Reduce Motion is on.
struct PinShake: ViewModifier {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
                view.offset(x: reduceMotion ? 0 : offset)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: 0.01)
                    LinearKeyframe(-12, duration: 0.07)
                    LinearKeyframe(12, duration: 0.07)
                    LinearKeyframe(-8, duration: 0.07)
                    LinearKeyframe(8, duration: 0.07)
                    LinearKeyframe(0, duration: 0.07)
                }
            }
            .sensoryFeedback(.error, trigger: trigger)
    }
}
