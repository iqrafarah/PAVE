import SwiftUI

/// A row in a panel that leads somewhere: an icon, a title and a line under it.
struct ShareLinkRow: View {
    let icon: ImageResource
    let title: String
    var detail: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.paveAccent)
                    .frame(width: 18, height: 18)
                    .frame(width: 36, height: 36)
                    .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 10))
                    .accessibilityHidden(true)
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
        .buttonStyle(.pave)
    }
}
