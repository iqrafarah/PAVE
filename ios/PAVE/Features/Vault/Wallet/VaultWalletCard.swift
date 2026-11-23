import PAVECore
import SwiftUI

/// One credential in the demo wallet, drawn the way wallet apps draw a pass: a coloured card per issuer with its
/// initials, the kind of credential, the title and when. Tapping chooses it; while it goes into the vault the check runs
/// at the bottom of the card. One that is already in the vault is greyed out and cannot be chosen.
struct VaultWalletCard: View {
    let credential: VaultWalletCredential
    let isSelected: Bool
    /// How many checks are done; nil while it is not being checked.
    let checksDone: Int?
    let action: () -> Void

    @Environment(\.paveReduceMotion) private var reduceMotion

    private var palette: VaultFolderColor { VaultWalletCard.color(for: credential.issuer) }
    private var foreground: Color { palette.foreground }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    issuerBadge
                    Text(credential.issuer)
                        .textStyle(.caption)
                        .foregroundStyle(foreground.opacity(0.9))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(credential.format)
                        .textStyle(.tag)
                        .foregroundStyle(foreground)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 22)
                        .background(foreground.opacity(0.16), in: .capsule)
                }
                Spacer(minLength: 22)
                Text(credential.title)
                    .textStyle(.choice)
                    .foregroundStyle(foreground)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !meta.isEmpty {
                    Text(meta)
                        .textStyle(.caption)
                        .foregroundStyle(foreground.opacity(0.82))
                        .padding(.top, 2)
                }
                HStack(alignment: .center, spacing: 8) {
                    status
                    Spacer(minLength: 8)
                    if !credential.imported {
                        selectionMark
                    }
                }
                .frame(minHeight: 28)
                .padding(.top, 12)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
            .background { cardBackground }
            .clipShape(.rect(cornerRadius: 20, style: .continuous))
            .saturation(credential.imported ? 0.25 : 1)
            .opacity(credential.imported ? 0.75 : 1)
            .overlay {
                // A ring around the card when it is chosen, as multi-select does elsewhere in iOS.
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.paveAccent, lineWidth: 2.5)
                    .padding(-5)
                    .opacity(isSelected ? 1 : 0)
            }
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.pave)
        .disabled(credential.imported)
        .padding(.horizontal, 5)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: isSelected)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: checksDone)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(credential.format), \(credential.title), \(credential.issuer)\(meta.isEmpty ? "" : ", \(meta)")")
        .accessibilityValue(accessibilityStatus)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// "jul 2024 · Eindhoven"
    private var meta: String {
        [credential.when, credential.place].compactMap { $0 }.joined(separator: " · ")
    }

    /// The colour of the issuer, a little darker towards the bottom, as wallet passes are.
    private var cardBackground: some View {
        LinearGradient(
            colors: [palette.color, palette.color.mix(with: .black, by: 0.12)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var issuerBadge: some View {
        Text(VaultWalletCard.initials(of: credential.issuer))
            .textStyle(.tag)
            .foregroundStyle(palette.color)
            .frame(width: 30, height: 30)
            .background(foreground, in: .circle)
            .accessibilityHidden(true)
    }

    private var selectionMark: some View {
        ZStack {
            Circle()
                .strokeBorder(foreground.opacity(0.75), lineWidth: 1.5)
                .opacity(isSelected ? 0 : 1)
            Circle()
                .fill(foreground)
                .opacity(isSelected ? 1 : 0)
            Image(.iconCheck)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(palette.color)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var status: some View {
        if credential.imported {
            seal(icon: .iconCheckBadgeSolid, text: VaultMessages.walletInVault)
        } else if let checksDone {
            if checksDone >= VaultWalletModel.Check.allCases.count {
                seal(icon: .iconShieldCheckSolid, text: VaultMessages.walletVerifiedSeal)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(foreground)
                    Text(VaultWalletModel.Check(rawValue: checksDone)?.progress ?? "")
                        .textStyle(.caption)
                        .foregroundStyle(foreground)
                        .contentTransition(.opacity)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(foreground.opacity(0.16), in: .capsule)
            }
        }
    }

    private func seal(icon: ImageResource, text: String) -> some View {
        HStack(spacing: 5) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
            Text(text)
                .textStyle(.caption)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .frame(minHeight: 28)
        .background(foreground.opacity(0.16), in: .capsule)
    }

    private var accessibilityStatus: String {
        if credential.imported { return VaultMessages.walletInVault }
        guard let checksDone else { return isSelected ? "Gekozen" : "Niet gekozen" }
        if checksDone >= VaultWalletModel.Check.allCases.count { return VaultMessages.walletVerifiedSeal }
        return VaultWalletModel.Check(rawValue: checksDone)?.progress ?? ""
    }

    /// The colour of an issuer's cards: the same for every card of that issuer, from the folder colours of the vault.
    static func color(for issuer: String) -> VaultFolderColor {
        let colors: [VaultFolderColor] = [.green, .blue, .purple, .rust, .rose]
        let sum = issuer.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return colors[sum % colors.count]
    }

    /// "HK" for Hogeschool Kempenland, "SN" for Studio Noord.
    static func initials(of issuer: String) -> String {
        let words = issuer.split(separator: " ").filter { $0.first?.isLetter == true }
        return String(words.prefix(2).compactMap(\.first)).uppercased()
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            VaultWalletCard(
                credential: VaultWalletCredential(id: "a", category: .badges, format: "Open Badge", title: "Samenwerken in een projectteam", issuer: "Hogeschool Kempenland", place: "Eindhoven", issuedOn: VaultDay(year: 2025, month: 1, day: 24)),
                isSelected: true, checksDone: 1
            ) {}
            VaultWalletCard(
                credential: VaultWalletCredential(id: "b", category: .internships, format: "Werkgeversverklaring", title: "Stage front-end development", issuer: "Studio Noord", place: "Eindhoven", startDate: VaultDay(year: 2025, month: 2, day: 3), endDate: VaultDay(year: 2025, month: 7, day: 4)),
                isSelected: false, checksDone: nil
            ) {}
            VaultWalletCard(
                credential: VaultWalletCredential(id: "c", category: .diplomas, format: "Diploma", title: "Propedeuse HBO-ICT", issuer: "Hogeschool Kempenland", issuedOn: VaultDay(year: 2024, month: 7, day: 12), imported: true),
                isSelected: false, checksDone: nil
            ) {}
        }
        .padding(24)
    }
}
