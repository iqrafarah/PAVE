import PAVECore
import SwiftUI

/// The top of Profiel: your card, as a pass in Wallet. Tap it and it turns to the QR code of what you share quickly;
/// Snel delen under it makes a new one, for anyone.
struct ShareProfileCard: View {
    let model: SharingModel
    let onQuickShare: () -> Void

    @Environment(ProfileModel.self) private var profile
    @Environment(VaultModel.self) private var vault
    @Environment(\.paveReduceMotion) private var reduceMotion
    @AppStorage(QuickShareSheet.lastShareKey) private var lastShareID = ""
    @State private var isTurned = false

    private var name: String { profile.profile.fullName ?? profile.profile.displayName ?? "" }

    /// As on the CV: the newest diploma, "Student …".
    private var headline: String? {
        vault.items
            .filter { $0.category == .diplomas }
            .max { ($0.period ?? "") < ($1.period ?? "") }
            .map { "Student \($0.title)" }
    }

    private var verified: [VaultItem] { vault.items.filter { $0.status == .verified && $0.archivedAt == nil } }
    private var quickShare: ProfileShare? { model.share(lastShareID).flatMap { $0.isLive() ? $0 : nil } }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: turn) {
                ZStack {
                    SharePassFront(name: name, photo: profile.avatar, headline: headline, verified: verified, total: vault.items.count)
                        .opacity(isTurned ? 0 : 1)
                    SharePassBack(share: quickShare, url: quickShare.flatMap(model.link(for:)), onMake: onQuickShare)
                        .opacity(isTurned ? 1 : 0)
                        // The back is drawn turned, so it reads the right way round once the card has turned.
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                }
                .rotation3DEffect(.degrees(isTurned && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .shadow(color: Color.paveAccentFill.opacity(0.25), radius: 16, y: 8)
            }
            .buttonStyle(.pave)
            .accessibilityLabel(isTurned ? SharingMessages.passBackLabel : SharingMessages.passFrontLabel(name))
            .accessibilityHint(SharingMessages.passTurn)
            Button(action: onQuickShare) {
                HStack(spacing: 8) {
                    Image(.iconQrcode)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(17)
                        .accessibilityHidden(true)
                    Text(SharingMessages.quickShare)
                        .textStyle(.button)
                }
                .foregroundStyle(Color.paveAccent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.paveSurfaceTint, in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.pave)
        }
        // A new quick share turns the card to its code.
        .onChange(of: lastShareID) { _, id in
            if !id.isEmpty, !isTurned { turn() }
        }
    }

    private func turn() {
        PaveHaptics.tap(.light)
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.2)) { isTurned.toggle() }
    }
}
