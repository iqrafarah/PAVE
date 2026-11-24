import PAVECore
import SwiftUI

/// Where a line comes from: a piece of evidence with its status, or typed by hand.
struct ApplicationSourceRow: View {
    let item: VaultItem?

    var body: some View {
        HStack(spacing: 8) {
            Image(item == nil ? .iconPencilSquareOutline : .iconVaultBuildingOutline)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(14)
                .foregroundStyle(Color.inkMuted)
                .accessibilityHidden(true)
            Text(item.map { "\(ApplyMessages.fromVault): \($0.title)" } ?? ApplyMessages.typedByHand)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let item {
                VaultStatusBadge(item: item)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
