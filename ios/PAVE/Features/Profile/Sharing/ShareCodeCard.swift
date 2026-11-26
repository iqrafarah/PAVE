import PAVECore
import SwiftUI

/// The QR code and the link of a share, with copying, sending and showing it on the Watch.
struct ShareCodeCard: View {
    let model: SharingModel
    let share: ProfileShare

    @State private var copied = false
    @State private var onWatch = false

    var body: some View {
        VStack(spacing: 14) {
            if let url = model.link(for: share) {
                ShareQRCode(url: url)
                    .frame(maxWidth: 240)
                Text(url.absoluteString)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                HStack(spacing: 10) {
                    PaveSecondaryButton(title: copied ? "Gekopieerd" : SharingMessages.copy) {
                        UIPasteboard.general.url = url
                        PaveHaptics.success()
                        copied = true
                    }
                    ShareLink(item: url, subject: Text(share.title), message: Text(share.title)) {
                        Text(SharingMessages.sendLink)
                            .textStyle(.button)
                            .foregroundStyle(Color.paveAccent)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.panel, in: .capsule)
                            .overlay { Capsule().strokeBorder(Color.paveAccent, lineWidth: 1.5) }
                    }
                }
                if ShareWatchBridge.isAvailable {
                    Button(onWatch ? SharingMessages.shownOnWatch : SharingMessages.showOnWatch) {
                        onWatch = ShareWatchBridge.show(share, url: url)
                    }
                    .textStyle(.link)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
                    .buttonStyle(.pave)
                    .disabled(onWatch)
                }
                if model.webURL?.host() == "localhost" {
                    Text(SharingMessages.localOnly).textStyle(.caption).foregroundStyle(Color.inkMuted).multilineTextAlignment(.center)
                }
            } else {
                PaveNotice(message: SharingMessages.noWebsite)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
