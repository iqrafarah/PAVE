import SwiftUI

/// A titled panel, as the sections of Meldingen and the verification request: a small label above, rows inside.
struct SharePanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .textStyle(.eyebrow)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 4)
            VStack(spacing: 0) { content }
                .background(Color.panel, in: .rect(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
        }
    }
}
