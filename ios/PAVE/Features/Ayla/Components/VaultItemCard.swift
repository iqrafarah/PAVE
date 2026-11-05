import SwiftUI

/// A vault item that the user can tick to let Ayla use it (Figma: "HAVO Diploma").
struct VaultItemCard: View {
    let title: String
    let organisation: String
    let period: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                CompanyMonogram(name: organisation)
                    .padding(.top, 9)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .textStyle(.bubble)
                        .foregroundStyle(Color.ink)
                        .padding(.top, 16)
                    VStack(alignment: .leading, spacing: 9) {
                        PaveIconLabel(icon: .iconBuilding, text: organisation)
                        PaveIconLabel(icon: .iconCalendar, text: period)
                    }
                    .padding(.leading, 5)
                    .padding(.top, 13.6)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PaveCheckbox(isOn: isSelected)
                    .padding(.top, 16)
                    .padding(.trailing, 17)
            }
            .padding(.leading, 9)
            .frame(maxWidth: .infinity, minHeight: 109, alignment: .leading)
            .background { FigmaCardGradient(tint: tint, start: UnitPoint(x: 0.77, y: 1.67), end: UnitPoint(x: 0.23, y: -0.67)) }
            .clipShape(.rect(cornerRadius: 17))
            .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Color.cardBorder, lineWidth: 1) }
            .contentShape(.rect(cornerRadius: 17))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: 13) {
        VaultItemCard(title: "Diploma", organisation: "Voorbeeldschool", period: "2020 - 2025", tint: .cardTintApricot, isSelected: true) {}
        VaultItemCard(title: "Bijbaan", organisation: "Voorbeeldwinkel", period: "Nov 2025 - nu", tint: .cardTintGreen, isSelected: false) {}
    }
    .padding(.leading, 25)
    .padding(.trailing, 26)
}
