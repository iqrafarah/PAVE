import PAVECore
import SwiftUI

/// One credential in the demo wallet: what it is, who issued it and when, with a checkbox. While it goes into the vault
/// the checks tick off under it; one that is already in the vault cannot be chosen.
struct VaultWalletCard: View {
    let credential: VaultWalletCredential
    let isSelected: Bool
    /// How many checks are done; nil while it is not being checked.
    let checksDone: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    icon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(credential.format)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                        Text(credential.title)
                            .textStyle(.label)
                            .foregroundStyle(Color.ink)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(issuerLine)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        if let when = credential.when {
                            Text(when)
                                .textStyle(.caption)
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !credential.imported {
                        PaveCheckbox(isOn: isSelected, size: 22)
                            .padding(.top, 2)
                    }
                }
                if credential.imported {
                    PaveIconLabel(icon: .iconInformationCircle, text: VaultMessages.walletInVault)
                } else if let checksDone {
                    VaultWalletChecks(done: checksDone)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .background(Color.panel, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.paveAccent : Color.railBorder, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(.rect(cornerRadius: 12))
            .opacity(credential.imported ? 0.7 : 1)
        }
        .buttonStyle(.pave)
        .disabled(credential.imported)
        .animation(.snappy(duration: 0.25), value: checksDone)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(credential.imported ? VaultMessages.walletInVault : "")
    }

    private var issuerLine: String {
        [credential.issuer, credential.place].compactMap { $0 }.joined(separator: ", ")
    }

    private var icon: some View {
        Image(credential.category.icon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .paveIconFrame(20)
            .foregroundStyle(Color.paveAccent)
            .frame(width: 40, height: 40)
            .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 12) {
        VaultWalletCard(
            credential: VaultWalletCredential(id: "a", category: .badges, format: "Open Badge", title: "Samenwerken in een projectteam", issuer: "Hogeschool Kempenland", place: "Eindhoven", issuedOn: VaultDay(year: 2025, month: 1, day: 24)),
            isSelected: true, checksDone: 2
        ) {}
        VaultWalletCard(
            credential: VaultWalletCredential(id: "b", category: .diplomas, format: "Diploma", title: "Propedeuse HBO-ICT", issuer: "Hogeschool Kempenland", issuedOn: VaultDay(year: 2024, month: 7, day: 12), imported: true),
            isSelected: false, checksDone: nil
        ) {}
    }
    .padding(24)
}
