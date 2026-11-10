import SwiftUI

/// How every PAVE button responds to a touch: a light tap you feel the moment you press it, as iOS does, and the
/// button gives a little. Use `.buttonStyle(.pave)` instead of `.plain`.
struct PaveButtonStyle: ButtonStyle {
    var haptic: UIImpactFeedbackGenerator.FeedbackStyle = .light

    func makeBody(configuration: Configuration) -> some View {
        PressedLabel(configuration: configuration, haptic: haptic)
    }

    private struct PressedLabel: View {
        let configuration: ButtonStyleConfiguration
        let haptic: UIImpactFeedbackGenerator.FeedbackStyle

        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.65 : 1)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .onChange(of: configuration.isPressed) { _, isPressed in
                    if isPressed, isEnabled { PaveHaptics.tap(haptic) }
                }
        }
    }
}

extension ButtonStyle where Self == PaveButtonStyle {
    static var pave: PaveButtonStyle { PaveButtonStyle() }
}
