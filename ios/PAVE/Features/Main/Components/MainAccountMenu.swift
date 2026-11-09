import SwiftUI

/// Your account at the bottom of the menu, as in ChatGPT and Claude: tap it for your settings or to sign out.
struct MainAccountMenu: View {
    let name: String?
    /// Settings are open: the badge gets the green ring of the open place.
    let isSettingsOpen: Bool
    let onSettings: () -> Void
    let onSignOut: () -> Void

    @State private var confirmsSignOut = false

    var body: some View {
        Menu {
            if let name {
                Text(name)
            }
            Button("Instellingen", image: .iconSettings, action: onSettings)
            Button("Uitloggen", image: .iconSignOut, role: .destructive) {
                confirmsSignOut = true
            }
        } label: {
            AccountBadge(name: name)
                .overlay {
                    if isSettingsOpen {
                        Circle().strokeBorder(Color.brandGreen, lineWidth: 2)
                    }
                }
        }
        .hoverEffect(.highlight)
        .accessibilityLabel("Je account")
        .confirmationDialog("Wil je uitloggen?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Uitloggen", role: .destructive, action: onSignOut)
        } message: {
            Text("Je pincode blijft op dit toestel bewaard.")
        }
    }
}

#Preview {
    MainAccountMenu(name: "Daaf", isSettingsOpen: false, onSettings: {}, onSignOut: {})
        .padding()
}
