import SwiftUI

/// At the top of the chat after a task from an application: back to that application in one tap, or away.
struct AylaBackToApplication: View {
    let company: String
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onOpen) {
                HStack(spacing: 8) {
                    Image(.iconArrowLeft)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(14)
                        .accessibilityHidden(true)
                    Text(ApplyMessages.backToApplicationAt(company))
                        .textStyle(.chip)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.ink)
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            Button(action: onDismiss) {
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(12)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 36, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel(ApplyMessages.close)
        }
        .padding(.trailing, 4)
        .background(Color.panel, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}

#Preview {
    AylaBackToApplication(company: "Kade Consultancy", onOpen: {}, onDismiss: {})
}
