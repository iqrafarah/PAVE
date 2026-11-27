import SwiftUI

/// A row that does something to a share right here: pause, extend, take back. Red for what cannot be undone.
struct ShareActionRow: View {
    let icon: ImageResource
    let title: String
    var isDestructive = false

    var body: some View {
        HStack(spacing: 14) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(17)
                .foregroundStyle(Color.white)
                .paveIconFrame(32)
                .background(isDestructive ? Color.critical : Color.paveAccentFill, in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)
            Text(title)
                .textStyle(.bodyMedium)
                .foregroundStyle(isDestructive ? Color.critical : Color.ink)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(.rect)
    }
}

#Preview {
    VStack(spacing: 0) {
        ShareActionRow(icon: .iconPauseSolid, title: "Pauzeer")
        ShareActionRow(icon: .iconTrashSolid, title: "Intrekken", isDestructive: true)
    }
    .background(Color.panel)
}
