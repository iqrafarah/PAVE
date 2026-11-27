import SwiftUI

/// A titled group of rows, as in Instellingen: a grey title in plain words above one white card.
struct SharePanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.inkMuted)
                .padding(.leading, 8)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content }
                .background(Color.panel, in: .rect(cornerRadius: 14))
        }
    }
}
