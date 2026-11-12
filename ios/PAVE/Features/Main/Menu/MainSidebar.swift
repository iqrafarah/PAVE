import SwiftUI

/// What the menu shows, laid out like ChatGPT: PAVE at the top with one button on the right, the places, and at
/// the bottom a new conversation on the left and your account on the right.
/// - `drawer` (iPhone, the open iPhone Duo held upright): the bell at the top right, your account at the bottom.
/// - `docked` (iPad, the open iPhone Duo held sideways): a button at the top right hides the sidebar; the bell and
///   your account share a capsule at the bottom.
/// - `pane` (next to the fold of a partly folded iPhone Duo): as `docked`, without the button to hide it.
/// - `beside` (outer display of iPhone Duo): only PAVE and the places; the buttons are in the bar along the side.
struct MainSidebar: View {
    enum Style {
        case drawer
        case docked
        case pane
        case beside
    }

    let style: Style
    let selection: MainDestination
    let name: String?
    let onSelect: (MainDestination) -> Void
    let onNewConversation: () -> Void
    let onSignOut: () -> Void
    /// Closes the drawer, or hides the docked sidebar.
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(.paveLogo)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                    .foregroundStyle(Color.paveAccent)
                    .padding(.leading, 12)
                    .accessibilityLabel("PAVE")
                Spacer(minLength: 8)
                switch style {
                case .drawer:
                    MainBellButton(isSelected: selection == .notifications) { onSelect(.notifications) }
                case .docked:
                    hideButton
                case .pane, .beside:
                    EmptyView()
                }
            }
            .frame(minHeight: 44)
            .padding(.bottom, 20)

            // Scrolls only when it does not fit (large text, a low screen); the bottom row stays in place.
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(MainDestination.main) { destination in
                        MainSidebarRow(destination: destination, isSelected: destination == selection) {
                            onSelect(destination)
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .padding(.bottom, 16)

            if style != .beside {
                HStack(spacing: 12) {
                    MainNewChatButton(action: onNewConversation)
                    if style == .docked || style == .pane {
                        MainAccountCapsule(axis: .horizontal, name: name, selection: selection, onSelect: onSelect, onSignOut: onSignOut)
                    } else {
                        MainAccountMenu(name: name, isSettingsOpen: selection == .settings, onSettings: { onSelect(.settings) }, onSignOut: onSignOut)
                    }
                }
            }
        }
    }

    private var hideButton: some View {
        Button(action: onClose) {
            Image(systemName: "rectangle.lefthalf.filled")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.ink)
                .paveIconFrame(44)
                .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .glassEffect(.regular.interactive(), in: .circle)
        .hoverEffect(.highlight)
        .accessibilityLabel("Menu verbergen")
    }
}

#Preview {
    MainSidebar(style: .docked, selection: .ayla, name: "Daaf", onSelect: { _ in }, onNewConversation: {}, onSignOut: {}, onClose: {})
        .padding(16)
        .frame(width: 300, height: 700)
        .background(Color.canvas)
}
