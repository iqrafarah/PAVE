import SwiftUI

/// The green tick that lands when evidence is in the vault, at the end of "Bewijs toevoegen" and of the wallet.
struct VaultAddedTick: View {
    let landed: Bool
    @Environment(\.isShortSheet) private var isShort

    var body: some View {
        let size: CGFloat = isShort ? 76 : 104
        Image(.iconCheck)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.42, height: size * 0.42)
            .foregroundStyle(.white)
            .scaleEffect(landed ? 1 : 0.4)
            .frame(width: size, height: size)
            .background(Color.paveAccentFill, in: .circle)
            .scaleEffect(landed ? 1 : 0.6)
            .opacity(landed ? 1 : 0)
            .accessibilityHidden(true)
    }
}

#Preview {
    VaultAddedTick(landed: true)
}
