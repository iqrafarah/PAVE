import SwiftUI

/// A tile with a vault category and its number of items (Figma: "Alle items, 50 items").
struct VaultCategoryTile: View {
    let title: String
    let count: Int
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .textStyle(.tileTitle)
                    .foregroundStyle(Color.black)
                Text(count == 1 ? "1 item" : "\(count) items")
                    .textStyle(.tileCount)
                    .foregroundStyle(Color.inkSoft)
                    .padding(.top, 3)
                PaveCheckbox(isOn: isOn, size: 15)
                    .padding(.top, 9)
            }
            .padding(.top, 10)
            .padding(.bottom, 11)
            .padding(.horizontal, 13)
            .frame(minWidth: 98)
            .background(Color.white, in: .rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cardBorder, lineWidth: 1) }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    HStack(spacing: 9) {
        VaultCategoryTile(title: "Alle items", count: 50, isOn: false) {}
        VaultCategoryTile(title: "Certificaten", count: 15, isOn: true) {}
    }
    .padding()
}
