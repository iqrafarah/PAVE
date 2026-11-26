import SwiftUI

/// The hairline between rows in a panel, starting after the icon, as in Instellingen.
struct ShareRowDivider: View {
    var inset: CGFloat = 60

    var body: some View {
        Rectangle()
            .fill(Color.railBorder)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}
