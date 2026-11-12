import PAVECore
import SwiftUI

/// Instellingen › Weergave (Figma FEDDIES 1393:5359): theme colour, how the vault opens and text size. Every choice
/// shows at once; Werkwijze from the design is left out.
struct SettingsAppearanceScreen: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        SettingsPage(title: SettingsMessages.appearance) {
            card(SettingsMessages.themeColor) {
                ThemeColorPicker(selection: profile.theme, customColor: profile.customColor) { theme in
                    Task { await profile.setTheme(theme) }
                } onCustomColor: { color in
                    profile.previewCustomColor(color)
                } onCustomColorDone: {
                    Task { await profile.saveCustomColor() }
                }
            }
            card(SettingsMessages.vaultLayout) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { vaultLayoutOptions }
                    VStack(spacing: 10) { vaultLayoutOptions }
                }
                Text(SettingsMessages.vaultLayoutHint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            card(SettingsMessages.textSize) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { textSizeOptions }
                    VStack(spacing: 10) { textSizeOptions }
                }
            }
            if profile.state == .ready, !profile.savesInAccount {
                Text(SettingsMessages.onThisDeviceOnly)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var vaultLayoutOptions: some View {
        ForEach(PaveVaultLayout.allCases) { layout in
            vaultLayoutOption(layout)
        }
    }

    private func vaultLayoutOption(_ layout: PaveVaultLayout) -> some View {
        let icon: ImageResource = layout == .list ? .iconListBulletSolid : .iconSquares2X2Solid
        return SettingsOptionCard(title: SettingsMessages.title(layout), isSelected: profile.vaultLayout == layout) {
            Image(icon).renderingMode(.template).paveIconScale()
        } action: {
            Task { await profile.setVaultLayout(layout) }
        }
    }

    private var textSizeOptions: some View {
        ForEach(PaveTextSize.allCases) { size in
            textSizeOption(size)
        }
    }

    private func textSizeOption(_ size: PaveTextSize) -> some View {
        SettingsOptionCard(title: SettingsMessages.title(size), isSelected: profile.textSize == size) {
            TextSizeGlyph(size: size)
        } action: {
            Task { await profile.setTextSize(size) }
        }
    }

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .textStyle(.label)
                .foregroundStyle(Color.ink)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: .rect(cornerRadius: 14))
    }
}
