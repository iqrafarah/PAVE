import PAVECore
import SwiftUI

/// Instellingen, like the iPhone's Settings app: your account on top, then rows that each open their own page. Weergave
/// follows the design (Figma FEDDIES 1393:5359; Werkwijze is left out).
struct SettingsScreen: View {
    let name: String?
    let onShowMenu: (() -> Void)?
    let onSignOut: () -> Void

    @AppStorage(AppState.lockAfterKey) private var lockAfter = AppState.defaultLockAfter
    @Environment(AylaMemoryModel.self) private var memory
    @Environment(ProfileModel.self) private var profile
    @State private var path: [SettingsDestination] = []
    @Environment(AylaPageDriver.self) private var driver: AylaPageDriver?

    /// The pages the Camera Control button can open, as the rows do.
    enum SettingsDestination: String, CaseIterable, Hashable {
        case appearance
        case devices
        case ayla
        case privacy
        case retention
        case archive

        var title: String {
            switch self {
            case .appearance: SettingsMessages.appearance
            case .devices: DevicesMessages.title
            case .ayla: "Ayla"
            case .privacy: "Privacy"
            case .retention: RetentionMessages.title
            case .archive: RetentionMessages.archiveTitle
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsProfileHeader(fallbackName: name, onSignOut: onSignOut)

                    SettingsSectionTitle(title: SettingsMessages.general)
                    SettingsGroup {
                        SettingsRow(icon: .iconPaintBrushSolid, title: SettingsMessages.appearance, value: SettingsMessages.title(profile.theme), opens: .appearance)
                        SettingsRow(icon: .iconDevicePhoneMobileSolid, title: DevicesMessages.title, opens: .devices)
                    }

                    SettingsSectionTitle(title: SettingsMessages.aylaAndPrivacy)
                    SettingsGroup {
                        SettingsRow(icon: .iconChatBubbleLeftEllipsisSolid, title: "Ayla", value: SettingsAylaScreen.memorySummary(memory).shortened, opens: .ayla)
                        SettingsRow(icon: .iconShieldCheckSolid, title: "Privacy", value: SettingsPrivacyScreen.lockTitle(lockAfter), opens: .privacy)
                    }

                    SettingsSectionTitle(title: "Je gegevens")
                    SettingsGroup {
                        SettingsRow(
                            icon: .iconClockSolid, title: RetentionMessages.title,
                            value: profile.retention.map { RetentionMessages.period($0.chatExpiry.days) }, opens: .retention
                        )
                        SettingsRow(icon: .iconArchiveBoxSolid, title: RetentionMessages.archiveTitle, opens: .archive)
                    }
                }
                .padding(.horizontal, 23)
                .padding(.top, 32)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas.ignoresSafeArea())
            .mainScreenToolbar("Instellingen", onShowMenu: onShowMenu)
            .task { await profile.load() }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .appearance: SettingsAppearanceScreen()
                case .devices: SignedInDevicesScreen()
                case .ayla: SettingsAylaScreen()
                case .privacy: SettingsPrivacyScreen()
                case .retention: SettingsRetentionScreen()
                case .archive: ArchiveScreen()
                }
            }
            // Ayla opens a page or goes back when you ask her to.
            .onChange(of: driver?.settingsPage, initial: true) {
                guard let page = driver?.settingsPage else { return }
                driver?.settingsPage = nil
                if path != [page] { path = [page] }
            }
            // Knopmodus: swipe through the pages, a full press opens the one it rests on.
            .cameraControlMenus("settings", menus: [
                CameraMenu(id: "settings-pages", title: "Instellingen", symbol: "gearshape", items: SettingsDestination.allCases.map(\.title), onPress: { index in
                    path = [SettingsDestination.allCases[index]]
                }),
            ])
        }
        .tint(.paveAccent)
    }
}

private extension String {
    /// A value next to a row stays short; the page itself says more.
    var shortened: String? { count <= 22 ? self : nil }
}

#Preview {
    SettingsScreen(name: "Daaf", onShowMenu: {}, onSignOut: {})
        .environment(AylaMemoryModel(service: nil))
        .environment(SignedInDevicesModel(service: nil))
        .environment(ProfileModel(service: nil))
        .environment(WatchConnectionModel())
}
