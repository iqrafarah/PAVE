import SwiftUI

/// A group of rows in one white card, like the iPhone's Settings app; rows are separated by a hairline.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    row
                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(Color.railBorder)
                            .frame(height: 1)
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .background(Color.panel, in: .rect(cornerRadius: 14))
    }
}

/// A row that opens a page in Instellingen: an icon in a tile of the accent colour, a title, the current value, and an
/// arrow.
struct SettingsRow<Destination: View>: View {
    let icon: ImageResource
    let title: String
    var value: String?
    /// The page as a place in the stack, so Ayla and the cameraknop can go there and back too.
    var opens: SettingsScreen.SettingsDestination?
    @ViewBuilder let destination: Destination

    var body: some View {
        Group {
            if let opens {
                NavigationLink(value: opens) { label }
            } else {
                NavigationLink {
                    destination
                } label: {
                    label
                }
            }
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
    }

    private var label: some View {
            HStack(spacing: 14) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(17)
                    .foregroundStyle(Color.white)
                    .paveIconFrame(32)
                    .background(Color.paveAccentFill, in: .rect(cornerRadius: 8))
                    .accessibilityHidden(true)
                Text(title)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
                Image(.iconChevronRightSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(14)
                    .foregroundStyle(Color.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .contentShape(.rect)
    }
}

extension SettingsRow where Destination == EmptyView {
    init(icon: ImageResource, title: String, value: String? = nil, opens: SettingsScreen.SettingsDestination) {
        self.init(icon: icon, title: title, value: value, opens: opens) { EmptyView() }
    }
}

/// On a page inside Instellingen: "ga terug" to Ayla goes back from the page on top, and Ayla knows there is a page
/// to go back from.
private struct AylaBackStep: ViewModifier {
    @Environment(AylaPageDriver.self) private var driver: AylaPageDriver?
    @Environment(\.dismiss) private var dismiss
    @State private var isOnTop = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                isOnTop = true
                driver?.settingsDepth += 1
            }
            .onDisappear {
                isOnTop = false
                driver?.settingsDepth -= 1
            }
            .onChange(of: driver?.backSteps) {
                if isOnTop { dismiss() }
            }
    }
}

extension View {
    func aylaBackStep() -> some View { modifier(AylaBackStep()) }
}

/// The top of Instellingen: your photo, name and e-mail; it opens your account.
struct SettingsProfileHeader: View {
    @Environment(ProfileModel.self) private var profile
    let fallbackName: String?
    let onSignOut: () -> Void

    private var name: String? { profile.profile.displayName ?? fallbackName }

    var body: some View {
        NavigationLink {
            SettingsAccountScreen(fallbackName: fallbackName, onSignOut: onSignOut)
        } label: {
            HStack(spacing: 14) {
                AccountBadge(name: name, image: profile.avatar, size: 60)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name ?? "Je account")
                        .textStyle(.emptyTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Text(profile.profile.email ?? SettingsMessages.accountSubtitle)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(.iconChevronRightSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(14)
                    .foregroundStyle(Color.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(Color.panel, in: .rect(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opent je account")
    }
}

/// A page inside Instellingen: the same canvas, width and spacing as the main page, with its own title.
struct SettingsPage<Content: View>: View {
    let title: String
    /// Knopmodus on this page; a full press goes back, as the back button does.
    var cameraMenus: [CameraMenu] = []
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.horizontal, 23)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .cameraControlMenus("settings-\(title)", menus: cameraMenus, press: { dismiss() })
        .aylaBackStep()
    }
}

/// A small grey title above a group, like "Weergave" or "Privacy".
struct SettingsSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.inkMuted)
            .padding(.leading, 8)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}
