import SwiftUI

/// "Zoeken" in the menu, above your account and the bell: looks like a search field and opens "Zoeken in PAVE".
struct MainSearchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(.iconSearch)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(18)
                    .foregroundStyle(Color.inkMuted)
                Text("Zoeken")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.white, in: .capsule)
            .overlay { Capsule().strokeBorder(Color.cardBorder) }
            .contentShape(.capsule)
        }
        .buttonStyle(.pave)
        .hoverEffect(.highlight)
        .accessibilityLabel("Zoeken in PAVE")
        .accessibilityHint("Zoekt in je chats, projecten en kluis")
    }
}
