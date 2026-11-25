import PAVECore
import SwiftUI

/// The back of your card: the QR code of what you share quickly right now, or a way to make one.
struct SharePassBack: View {
    /// The quick share that is live, if there is one.
    let share: ProfileShare?
    let url: URL?
    let onMake: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let share, let url {
                ShareQRCode(url: url)
                    .frame(maxWidth: 170)
                QuickShareLookStatus(share: share)
                Text(SharingMessages.quickShareEnds(share.expiresAt))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
            } else {
                Image(.iconQrcode)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(36)
                    .foregroundStyle(Color.paveAccent)
                    .accessibilityHidden(true)
                Text(SharingMessages.passNoCode)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                PavePrimaryButton(title: SharingMessages.quickShareMake, action: onMake)
                    .frame(maxWidth: 260)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 210)
        .background(Color.panel, in: .rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.paveAccentFill, lineWidth: 2) }
    }
}
