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
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.ink)
                .frame(width: 36, height: 36)
                .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Naar het nieuwste bericht")
    }
}

#Preview {
    ChatScrollDownButton {}
        .padding()
        .background(Color.canvas)
}
