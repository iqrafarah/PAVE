import SwiftUI

/// Two thin lines with "Of" in between, between two ways to do the same thing.
struct VaultOrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            line
            Text("Of")
                .textStyle(.gapChip)
                .foregroundStyle(Color.ink)
            line
        }
        .accessibilityHidden(true)
    }

    private var line: some View {
        Capsule()
            .fill(Color.railBorder)
            .frame(height: 1)
    }
}

#Preview {
    VaultOrDivider()
        .padding(24)
}
