import SwiftUI

/// The icon at the start of a row: a solid icon in white on a tile of the accent colour, the same as in Instellingen.
struct ShareRowIcon: View {
    let icon: ImageResource
    var isMuted = false

    var body: some View {
        Image(icon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .paveIconFrame(17)
            .foregroundStyle(Color.white)
            .paveIconFrame(32)
            .background(isMuted ? Color.inkMuted.opacity(0.55) : Color.paveAccentFill, in: .rect(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ShareRowIcon(icon: .iconCamera)
        ShareRowIcon(icon: .iconClockSolid, isMuted: true)
    }
}
