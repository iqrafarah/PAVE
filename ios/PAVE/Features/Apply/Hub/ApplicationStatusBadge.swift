import PAVECore
import SwiftUI

/// Where an application stands, as a small coloured pill: grey while it is a draft, green once it is out, red when it
/// was turned down.
struct ApplicationStatusBadge: View {
    let status: ApplicationStatus

    private var colors: (ink: Color, fill: Color) {
        switch status {
        case .concept: (Color.inkMuted, Color.tileFill)
        case .sent, .interview, .offer: (Color.paveAccent, Color.statusVerifiedSurface)
        case .rejected: (Color.statusRejected, Color.statusRejectedSurface)
        }
    }

    var body: some View {
        Text(ApplyMessages.status(status))
            .textStyle(.caption)
            .foregroundStyle(colors.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .background(colors.fill, in: .capsule)
            .fixedSize()
    }
}

#Preview {
    HStack {
        ApplicationStatusBadge(status: .concept)
        ApplicationStatusBadge(status: .sent)
        ApplicationStatusBadge(status: .rejected)
    }
}
