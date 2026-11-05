import SwiftUI

/// A round white badge with the first letter of a company, used when there is no logo.
struct CompanyMonogram: View {
    let name: String
    var size: CGFloat = 64

    var body: some View {
        Text(name.prefix(1).uppercased())
            .font(.custom("InterVariable-Bold", size: size * 26 / 64, relativeTo: .title2))
            .foregroundStyle(Color.brandGreen)
            .frame(width: size, height: size)
            .background(Color.white, in: .circle)
            .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        CompanyMonogram(name: "Pixelwerk")
        CompanyMonogram(name: "Golfstroom")
    }
    .padding()
    .background(Color.canvas)
}
