import SwiftUI

/// The title above a group in Meldingen that can be folded away: tap it to hide or show its rows. Folded, it says how
/// many wait inside.
struct NotificationSectionHeader: View {
    let title: String
    let count: Int
    @Binding var isCollapsed: Bool

    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            PaveHaptics.selection()
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { isCollapsed.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(isCollapsed ? "\(title) · \(count)" : title)
                    .textStyle(.caption)
                    .foregroundStyle(Color.paveAccent)
                    .contentTransition(.opacity)
                Spacer(minLength: 8)
                Image(.iconChevronRightSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.paveAccent)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 32)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .accessibilityLabel(title)
        .accessibilityValue(isCollapsed ? "Ingeklapt, \(count)" : "Uitgeklapt")
        .accessibilityHint(isCollapsed ? "Tik om te tonen" : "Tik om in te klappen")
        .accessibilityAddTraits(.isHeader)
    }
}
