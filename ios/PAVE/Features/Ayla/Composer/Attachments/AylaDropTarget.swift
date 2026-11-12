import SwiftUI

/// While a file is dragged over the chat: where to let go.
struct AylaDropTarget: View {
    var body: some View {
        ZStack {
            Color.canvas.opacity(0.75)
            VStack(spacing: 12) {
                Image(.iconPaperclip)
                    .renderingMode(.template)
                    .foregroundStyle(Color.paveAccent)
                    .frame(width: 52, height: 52)
                    .background(Color.paveSurfaceTint, in: .circle)
                Text("Laat los om aan je bericht toe te voegen")
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                Text("Een pdf, foto of tekstbestand. Alleen de tekst gaat naar Ayla.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .multilineTextAlignment(.center)
            .padding(28)
            .glassEffect(.regular, in: .rect(cornerRadius: 25))
            .padding(32)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.paveAccent, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(12)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    AylaDropTarget()
}
