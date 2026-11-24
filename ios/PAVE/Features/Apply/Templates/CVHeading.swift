import SwiftUI

/// The title of a part of the CV, in the page's colour.
struct CVHeading: View {
    let title: String
    let accent: Color
    var size: CGFloat = 10.5
    var showsRule = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(ApplicationPage.font(size, .bold))
                .tracking(0.8)
                .foregroundStyle(accent)
            if showsRule {
                Rectangle()
                    .fill(accent.opacity(0.35))
                    .frame(height: 0.8)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}
