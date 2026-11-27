import SwiftUI

/// The last step of the wallet: the tick lands as at the end of "Bewijs toevoegen", then the card about Ayla rises in.
/// It starts off, as for any new evidence.
struct VaultWalletDoneView: View {
    @Bindable var wallet: VaultWalletModel
    @Environment(\.paveReduceMotion) private var reduceMotion
    @Environment(\.isShortSheet) private var isShort
    @State private var landed = false
    @State private var consentShown = false

    var body: some View {
        VStack(spacing: isShort ? 14 : 22) {
            Spacer(minLength: 0)
            VaultAddedTick(landed: landed)
            VStack(spacing: 8) {
                Text(VaultMessages.walletDoneTitle)
                    .textStyle(isShort ? .emptyTitle : .welcomeTitle)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(VaultMessages.walletAdded(wallet.itemIDs.count))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            Spacer(minLength: 0)
            VaultAylaConsentCard(isOn: $wallet.allowsAyla, hasFile: false, title: VaultMessages.walletAylaConsent(wallet.itemIDs.count))
                .opacity(consentShown ? 1 : 0)
                .offset(y: consentShown ? 0 : 16)
        }
        .frame(maxWidth: .infinity)
        .task {
            guard !landed else { return }
            AccessibilityNotification.Announcement(VaultMessages.walletAdded(wallet.itemIDs.count)).post()
            if reduceMotion {
                landed = true
                consentShown = true
                return
            }
            withAnimation(.spring(duration: 0.5, bounce: 0.35)) { landed = true }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { consentShown = true }
        }
    }
}
