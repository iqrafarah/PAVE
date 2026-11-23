import PAVECore
import SwiftUI

/// One credential from the demo wallet, drawn as the card it becomes in the vault (the tile of the grid, Figma 1348:9):
/// the band in the colour of its kind with the issuer's avatar, the title, where and when, and its skills. Choosing it
/// shows the outline and the tick of a chosen vault card. While it is checked, the badge in the band runs from
/// "Controleren" to "Geverifieerd", as it will stand in the vault.
struct VaultWalletCard: View {
    enum Mode: Equatable {
        /// Choosing: a checkbox in the band.
        case choose(isSelected: Bool)
        /// Being checked: how many of the checks are done.
        case checking(done: Int)
    }

    let credential: VaultWalletCredential
    let mode: Mode
    var action: () -> Void = {}

    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var logoLook: VaultLogoLook?

    private var isSelected: Bool { mode == .choose(isSelected: true) }
    private var checksDone: Int? {
        if case .checking(let done) = mode { return done }
        return nil
    }
    private var isVerified: Bool { (checksDone ?? 0) >= VaultWalletModel.Check.allCases.count }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                band
                VStack(alignment: .leading, spacing: 8) {
                    Text(credential.format)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                    Text(credential.title)
                        .textStyle(.bubble)
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -4)
                    PaveIconLabel(icon: .iconVaultBuildingOutline, text: [credential.issuer, credential.place].compactMap { $0 }.joined(separator: ", "))
                        .lineLimit(1)
                    if let when = credential.when {
                        PaveIconLabel(icon: .iconVaultCalendarOutline, text: when)
                            .lineLimit(1)
                    }
                    if let checksDone, !isVerified {
                        progress(checksDone)
                            .transition(.opacity)
                    } else if !credential.skills.isEmpty {
                        skills
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 32)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.panel)
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.paveAccent : Color.cardBorder, lineWidth: isSelected ? 2 : 1)
            }
            .opacity(credential.imported ? 0.55 : 1)
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.pave)
        .disabled(credential.imported || checksDone != nil)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isSelected)
        .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.35), value: isVerified)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .task(id: credential.id) {
            guard let data = credential.logo?.data else { logoLook = nil; return }
            let look = await VaultLogoLook.make(from: data)
            withAnimation(.easeOut(duration: 0.25)) { logoLook = look }
        }
    }

    /// A light tint of the logo's colour, or of the kind of evidence, with the avatar over its edge, as on a vault tile.
    private var band: some View {
        (logoLook?.tint ?? credential.category.tint)
            .frame(height: 52)
            .overlay(alignment: .bottomLeading) {
                VaultWalletAvatar(look: logoLook, category: credential.category, size: 48)
                    .padding(.leading, 14)
                    .offset(y: 24)
            }
            .overlay(alignment: .topTrailing) {
                corner
                    .padding(10)
            }
            .zIndex(1)
    }

    @ViewBuilder
    private var corner: some View {
        if credential.imported {
            VaultStatusBadge(status: .verified)
        } else if let checksDone {
            if checksDone >= VaultWalletModel.Check.allCases.count {
                VaultStatusBadge(status: .verified)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                VaultWalletCheckingBadge()
                    .transition(.opacity)
            }
        } else {
            PaveCheckbox(isOn: isSelected, size: 22)
                .padding(4)
                .background(Color.panel, in: .rect(cornerRadius: 7))
        }
    }

    /// The check that runs now, with the three as small steps.
    private func progress(_ done: Int) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(VaultWalletModel.Check.allCases, id: \.self) { check in
                    Capsule()
                        .fill(check.rawValue < done ? Color.paveAccent : Color.railBorder)
                        .frame(width: 14, height: 4)
                }
            }
            Text(VaultWalletModel.Check(rawValue: done)?.progress ?? "")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: done)
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    private var skills: some View {
        HStack(spacing: 6) {
            ForEach(credential.skills.prefix(2), id: \.self) { VaultSkillChip(text: $0) }
            if credential.skills.count > 2 {
                VaultSkillChip(text: "+\(credential.skills.count - 2)")
            }
        }
        .padding(.top, 2)
    }

    private var accessibilityLabel: String {
        ([credential.format, credential.title, credential.issuer, credential.when].compactMap { $0 }).joined(separator: ", ")
    }

    private var accessibilityValue: String {
        if credential.imported { return VaultMessages.walletInVault }
        if let checksDone {
            return isVerified ? VaultItem.Status.verified.title : VaultWalletModel.Check(rawValue: checksDone)?.progress ?? ""
        }
        return isSelected ? "Gekozen" : "Niet gekozen"
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            VaultWalletCard(
                credential: VaultWalletCredential(id: "a", category: .badges, format: "Open Badge", title: "Samenwerken in een projectteam", issuer: "Hogeschool Kempenland", place: "Eindhoven", issuedOn: VaultDay(year: 2025, month: 1, day: 24), skills: ["Samenwerken", "Plannen"]),
                mode: .choose(isSelected: true)
            )
            VaultWalletCard(
                credential: VaultWalletCredential(id: "b", category: .internships, format: "Werkgeversverklaring", title: "Stage front-end development", issuer: "Studio Noord", place: "Eindhoven", startDate: VaultDay(year: 2025, month: 2, day: 3), endDate: VaultDay(year: 2025, month: 7, day: 4)),
                mode: .checking(done: 1)
            )
        }
        .padding(24)
    }
}
