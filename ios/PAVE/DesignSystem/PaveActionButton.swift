import SwiftUI

/// A wide green button, such as "Nieuw gesprek". The glass version floats over a list, such as "Terug naar gesprek".
struct PaveActionButton: View {
    enum Style {
        case tinted
        case glass
    }

    let title: String
    var icon: ImageResource?
    var style = Style.tinted
    var cornerRadius: CGFloat = 14
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                if let icon {
                    Image(icon)
                        .renderingMode(.template)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .textStyle(.action)
            }
            .foregroundStyle(Color.brandGreen)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                if style == .tinted {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(Color.surfaceTint)
                }
            }
            .contentShape(.rect(cornerRadius: cornerRadius))
        }
        .buttonStyle(.pave)
        .glassEffect(style == .glass ? .regular.tint(Color.surfaceTint.opacity(0.75)).interactive() : .identity, in: .rect(cornerRadius: cornerRadius))
    }
}

#Preview {
    VStack(spacing: 16) {
        PaveActionButton(title: "Nieuw gesprek", icon: .iconCompose) {}
        PaveActionButton(title: "Terug naar gesprek", style: .glass, cornerRadius: 25) {}
    }
    .padding()
    .background(Color.canvas)
}
