import SwiftUI

/// A quiet grey capsule next to the green primary button, such as Terug in a flow with steps.
struct PaveSoftButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(.button)
        }
        .buttonStyle(SoftButtonStyle())
    }
}

private struct SoftButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color.ink : .inkMuted)
            .frame(maxWidth: .infinity, minHeight: 53)
            .padding(.horizontal, 16)
            .background(Color.railBorder, in: .capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed, isEnabled { PaveHaptics.tap(.light) }
            }
    }
}

#Preview {
    HStack(spacing: 8) {
        PaveSoftButton(title: "Terug") {}
        PavePrimaryButton(title: "Volgende") {}
    }
    .padding(24)
}
