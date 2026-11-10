import SwiftUI

/// The bell and your account together in one glass capsule, as ChatGPT does with search and your account:
/// side by side at the bottom of the sidebar, or one above the other in the bar along the side of iPhone Duo.
struct MainAccountCapsule: View {
    let axis: Axis
    let name: String?
    let selection: MainDestination
    let onSelect: (MainDestination) -> Void
    let onSignOut: () -> Void

    var body: some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 2)) : AnyLayout(VStackLayout(spacing: 2))
        layout {
            MainBellButton(isSelected: selection == .notifications, isPlain: true) { onSelect(.notifications) }
            MainAccountMenu(name: name, isSettingsOpen: selection == .settings, onSettings: { onSelect(.settings) }, onSignOut: onSignOut)
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
    }
}

#Preview {
    VStack(spacing: 30) {
        MainAccountCapsule(axis: .horizontal, name: "Daaf", selection: .ayla, onSelect: { _ in }, onSignOut: {})
        MainAccountCapsule(axis: .vertical, name: "Daaf", selection: .settings, onSelect: { _ in }, onSignOut: {})
    }
    .padding()
    .background(Color.canvas)
}
