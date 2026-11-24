import SwiftUI

/// What the tick on the CV means, small at the foot of the page: who verified it, and where.
struct CVVerifiedNote: View {
    let theme: ApplicationTheme

    var body: some View {
        HStack(spacing: 4) {
            Image(.iconCheckBadgeOutline)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 8.5, height: 8.5)
                .foregroundStyle(theme.accent)
            Text(ApplyMessages.verifiedNote)
                .font(theme.body(7.5))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ApplyMessages.verifiedNote)
    }
}
