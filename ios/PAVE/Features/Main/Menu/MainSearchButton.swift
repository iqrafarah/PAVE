import SwiftUI

/// "Zoeken in PAVE" as an icon next to the bell, as ChatGPT has search next to your account. Inside the glass capsule
/// (`isPlain`) only the magnifier; on its own it gets the same grey circle as the bell.
struct MainSearchButton: View {
    var isPlain = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(.iconSearch)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(20)
                .foregroundStyle(Color.ink)
                .frame(width: 44, height: 44)
                .background {
                    if !isPlain { Circle().fill(Color.cardBorder) }
                }
                .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .hoverEffect(.highlight)
        .accessibilityLabel("Zoeken in PAVE")
        .accessibilityHint("Zoekt in je chats, projecten en kluis")
    }
}
