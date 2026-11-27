import SwiftUI

/// "Controleren" in the shape of the status badge, while a credential from the wallet is being checked. It becomes the
/// "Geverifieerd" badge the evidence will have in the vault.
struct VaultWalletCheckingBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.mini)
                .tint(Color.statusPending)
            Text(VaultMessages.walletCheckingBadge)
                .textStyle(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(Color.statusPending)
        .padding(.leading, 5)
        .padding(.trailing, 6)
        .frame(minHeight: 24)
        .background(Color.statusPendingSurface, in: .rect(cornerRadius: 6))
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VaultWalletCheckingBadge()
        .padding()
}
