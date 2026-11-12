import SwiftUI

/// Starts a new conversation with Ayla from the menu, wherever you are: a green pill at the bottom of the menu, like
/// ChatGPT, filling the room next to your account.
struct MainNewChatButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(.iconCompose)
                    .renderingMode(.template)
                // One fixed layout, so nothing changes while the menu slides in; with very large text it shrinks a
                // little instead of running out of the menu.
                Text("Nieuw gesprek")
                    .textStyle(.listTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.paveAccent, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.pave)
        .hoverEffect(.highlight)
        .accessibilityLabel("Nieuw gesprek")
    }
}

#Preview {
    MainNewChatButton {}
        .padding()
}
