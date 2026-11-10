import SwiftUI

/// A small grey line with an icon in front, such as the company or the salary on a card.
struct PaveIconLabel: View {
    let icon: ImageResource
    let text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(icon)
                .renderingMode(.template)
                .foregroundStyle(Color.inkMuted)
                .frame(width: 17, height: 17)
                .accessibilityHidden(true)
            Text(text)
                .textStyle(.meta)
                .foregroundStyle(Color.inkMuted)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        PaveIconLabel(icon: .iconBuilding, text: "Pixelwerk - Eindhoven")
        PaveIconLabel(icon: .iconBriefcase, text: "Fulltime")
        PaveIconLabel(icon: .iconEuro, text: "€2.800 - €3.400 p/m")
    }
    .padding()
}
