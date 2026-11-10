import SwiftUI

struct PavePrimaryButton: View {
    let title: String
    var loadingTitle: String?
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    SpinningIcon()
                }
                Text(isLoading ? loadingTitle ?? title : title)
                    .textStyle(.button)
            }
        }
        .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
        .disabled(isLoading)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let isLoading: Bool

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, isLoading: isLoading)
    }
}

private struct PrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isLoading: Bool

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .foregroundStyle(isLoading ? Color.brandGreen : isEnabled ? .white : .inkMuted)
            .frame(maxWidth: .infinity, minHeight: 53)
            .padding(.horizontal, 16)
            .background(isLoading || !isEnabled ? Color.controlDisabled : .brandGreen, in: .capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isEnabled)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed, !isLoading, isEnabled { PaveHaptics.tap(.medium) }
            }
    }
}

private struct SpinningIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSpinning = false

    var body: some View {
        Image(.iconRefresh)
            .resizable()
            .frame(width: 20, height: 20)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear { isSpinning = true }
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 16) {
        PavePrimaryButton(title: "Inloggen") {}
        PavePrimaryButton(title: "Inloggen", loadingTitle: "Bezig met inloggen...", isLoading: true) {}
        PavePrimaryButton(title: "Wachtwoord opslaan") {}
            .disabled(true)
    }
    .padding(32)
    .background(Color.canvas)
}
