import SwiftUI

/// Instellingen › Account, like the account page in the iPhone's Settings: your photo, the name Ayla uses, the details
/// from your school, and signing out.
struct SettingsAccountScreen: View {
    let fallbackName: String?
    let onSignOut: () -> Void
    @State private var confirmsSignOut = false

    var body: some View {
        SettingsPage(title: SettingsMessages.account) {
            ProfileAccountSection(fallbackName: fallbackName)
            PaveActionButton(title: "Uitloggen") { confirmsSignOut = true }
                .padding(.top, 8)
                .confirmationDialog("Wil je uitloggen?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
                    Button("Uitloggen", role: .destructive, action: onSignOut)
                } message: {
                    Text("Je pincode blijft op dit toestel bewaard.")
                }
        }
    }
}
