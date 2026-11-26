import SwiftUI

/// A row in a panel that leads somewhere: an icon, a title and a line under it.
struct ShareLinkRow: View {
    let icon: ImageResource
    let title: String
    var detail: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) { Self.label(icon: icon, title: title, detail: detail) }
            .buttonStyle(.pave)
    }

    /// The row's look, also for a NavigationLink.
    static func label(icon: ImageResource, title: String, detail: String?) -> some View {
        HStack(spacing: 14) {
            ShareRowIcon(icon: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                if let detail {
                    Text(detail)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            Image(.iconChevronRightSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
                .foregroundStyle(Color.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(.rect)
    }
}
