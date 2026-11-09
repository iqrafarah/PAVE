import SwiftUI

/// Settings: your account, signing out and privacy. More settings come later (planned for week 4).
struct SettingsScreen: View {
    let name: String?
    let onShowMenu: (() -> Void)?
    let onSignOut: () -> Void

    @State private var confirmsSignOut = false
    @AppStorage(AylaSpotlight.settingKey) private var chatsInSpotlight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account")
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.leading, 8)
                        .accessibilityAddTraits(.isHeader)

                    HStack(spacing: 12) {
                        AccountBadge(name: name)
                        Text(name ?? "Je account")
                            .textStyle(.listTitle)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Color.white, in: .rect(cornerRadius: 14))

                    PaveActionButton(title: "Uitloggen") { confirmsSignOut = true }
                        .confirmationDialog("Wil je uitloggen?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
                            Button("Uitloggen", role: .destructive, action: onSignOut)
                        } message: {
                            Text("Je pincode blijft op dit toestel bewaard.")
                        }

                    Text("Privacy")
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.leading, 8)
                        .padding(.top, 20)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $chatsInSpotlight) {
                            Text("Chats vindbaar in iPhone-zoeken")
                                .textStyle(.listTitle)
                                .foregroundStyle(Color.ink)
                        }
                        .tint(.brandGreen)
                        Text("De titels van je chats met Ayla komen in de zoekfunctie van je iPhone, zodat je een chat snel terugvindt. Alleen de titels, niet wat erin staat. Zet je dit uit of log je uit, dan haalt PAVE ze er meteen weer uit.")
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(12)
                    .background(Color.white, in: .rect(cornerRadius: 14))
                }
                .padding(.horizontal, 23)
                .padding(.top, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas.ignoresSafeArea())
            .mainScreenToolbar("Instellingen", onShowMenu: onShowMenu)
        }
    }
}

#Preview {
    SettingsScreen(name: "Daaf", onShowMenu: {}, onSignOut: {})
}
