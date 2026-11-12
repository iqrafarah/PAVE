import SwiftUI

/// One of the two cover choices: a small picture of the card and its name, green when chosen.
struct VaultCoverOption: View {
    let title: String
    let image: ImageResource
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 80)
                    .clipShape(.rect(topLeadingRadius: 10, topTrailingRadius: 10))
                    .accessibilityHidden(true)
                Text(title)
                    .textStyle(.gapChip)
                    .foregroundStyle(Color.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 139)
            .background(isSelected ? Color.dropZone : .white, in: .rect(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(isSelected ? Color.brandGreen : .railBorder, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: 7))
        }
        .buttonStyle(.pave)
        .animation(.snappy(duration: 0.25), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack(spacing: 12) {
        VaultCoverOption(title: "Geen omslag", image: .vaultCoverNone, isSelected: false) {}
        VaultCoverOption(title: "Omslag", image: .vaultCoverPhoto, isSelected: true) {}
    }
    .padding(24)
}
