import SwiftUI

/// The last tile of the folder row when there are more folders than it shows: opens "Alle mappen".
struct VaultAllFoldersTile: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(.iconSquares2X2Solid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(22)
                    .foregroundStyle(Color.paveAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.paveSurfaceTint, in: .circle)
                Text(VaultMessages.allFolders(count))
                    .textStyle(.caption)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 10)
            .frame(width: 110)
            .frame(maxHeight: .infinity)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.pave)
        .accessibilityHint("Opent een overzicht van al je mappen")
    }
}
