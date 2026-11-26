import SwiftUI

/// A round white badge with a building, used when a company has no logo: an icon, never its first letter.
struct CompanyIconBadge: View {
    var size: CGFloat = 64
    /// A school gets a cap instead of a building.
    var icon: ImageResource = .iconBuilding

    var body: some View {
        Image(icon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.34, height: size * 0.34)
            .foregroundStyle(Color.paveAccent)
            .frame(width: size, height: size)
            .background(Color.panel, in: .circle)
            .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        CompanyIconBadge()
        CompanyIconBadge(size: 44)
    }
    .padding()
    .background(Color.canvas)
}
