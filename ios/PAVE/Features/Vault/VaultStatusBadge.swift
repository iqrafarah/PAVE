import PAVECore
import SwiftUI

/// Whether an item is confirmed, with the colours from the design.
struct VaultStatusBadge: View {
    let status: VaultItem.Status

    var body: some View {
        HStack(spacing: 3) {
            Image(status.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
            Text(status.title)
                .textStyle(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(status.foreground)
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .frame(minHeight: 24)
        .background(status.background, in: .rect(cornerRadius: 6))
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.title)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(VaultItem.Status.allCases, id: \.self) { VaultStatusBadge(status: $0) }
    }
    .padding()
}
