import SwiftUI

/// Notifications: the bell from the web sidebar (Figma 1726:149), with its own grey circle. The circle fills with the accent when open.
/// Inside a glass capsule (`isPlain`) only the bell itself, so there is no circle within the glass.
struct MainBellButton: View {
    /// Set by `MainView`: how many meldingen are unread.
    @Environment(\.unreadNotifications) private var unread
    let isSelected: Bool
    var isPlain = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            bell
                .overlay(alignment: .topTrailing) {
                    if unread > 0 {
                        Text(unread > 9 ? "9+" : "\(unread)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.paveAccentFill, in: .capsule)
                            .overlay { Capsule().strokeBorder(Color.canvas, lineWidth: 1.5) }
                            .offset(x: 2, y: 2)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .hoverEffect(.highlight)
        .accessibilityLabel("Meldingen")
        .accessibilityValue(unread > 0 ? "\(unread) ongelezen" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var bell: some View {
        if isPlain {
            // The Figma bell has its grey circle built in, so inside the glass capsule it is the plain Heroicon.
            Image(.iconBellSolid)
                .resizable()
                .scaledToFit()
                .paveIconFrame(20)
                .foregroundStyle(isSelected ? Color.paveAccent : Color.ink)
                .paveIconFrame(44)
        } else if isSelected {
            // Open: the grey circle turns accent and the bell white, instead of a ring around it.
            Image(.iconBellSolid)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.white)
                .frame(width: 36, height: 36)
                .background(Color.paveAccentFill, in: .circle)
        } else {
            Image(.iconBell)
        }
    }
}

extension EnvironmentValues {
    @Entry var unreadNotifications = 0
}

#Preview {
    HStack {
        MainBellButton(isSelected: false) {}
        MainBellButton(isSelected: true) {}
    }
    .padding()
}
