import SwiftUI

struct PaveSecondaryButton: View {
    let title: String
    var icon: ImageResource?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .textStyle(.button)
            }
        }
        .buttonStyle(SecondaryButtonStyle())
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color.brandGreen : .inkMuted)
            .frame(maxWidth: .infinity, minHeight: 53)
            .padding(.horizontal, 16)
            .background(Color.white, in: .capsule)
            .overlay {
                Capsule().strokeBorder(isEnabled ? Color.brandGreen : .hairline, lineWidth: 1.5)
            }
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    PaveSecondaryButton(title: "Instellen op deze iPhone", icon: .iconShieldCheck) {}
        .padding(32)
        .background(Color.canvas)
}
