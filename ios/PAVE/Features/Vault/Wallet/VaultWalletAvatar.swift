import PAVECore
import SwiftUI

/// The round avatar of a credential from the wallet: the issuer's logo, as in the vault; without one, the icon of its
/// kind (a cap for a diploma, a star for a badge). Never letters.
struct VaultWalletAvatar: View {
    let look: VaultLogoLook?
    let category: VaultCategory
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let look {
                VaultLogoAvatar(look: look, name: "", size: size)
            } else {
                Image(category.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.46, height: size * 0.46)
                    .foregroundStyle(Color.paveAccent)
                    .frame(width: size, height: size)
                    .background(Color.panel, in: .circle)
                    .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
                    .transition(.opacity)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        VaultWalletAvatar(look: nil, category: .diplomas)
        VaultWalletAvatar(look: nil, category: .badges)
        VaultWalletAvatar(look: nil, category: .internships)
    }
    .padding()
}
