import SwiftUI

/// The small glass button that appears when you have scrolled up in the conversation, to go back to the newest
/// message.
struct ChatScrollDownButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            PaveHaptics.tap(.light)
            action()
        } label: {
            Image(.iconArrowDown)
                .resizable()
                .scaledToFit()
                .paveIconFrame(16)
                .foregroundStyle(Color.ink)
                .paveIconFrame(36)
                .glassEffect(.regular.interactive(), in: .circle)
                // A 36 pt circle with a 44 pt area to tap.
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .accessibilityLabel("Naar het nieuwste bericht")
    }
}

#Preview {
    ChatScrollDownButton {}
        .padding()
        .background(Color.canvas)
}
