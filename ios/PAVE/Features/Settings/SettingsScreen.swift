import SwiftUI

/// Settings: your account, where you are signed in, signing out and privacy. More settings come later (planned for week 4).
struct SettingsScreen: View {
    let name: String?
    let onShowMenu: (() -> Void)?
    let onSignOut: () -> Void

    @State private var confirmsSignOut = false
    @AppStorage(AylaSpotlight.settingKey) private var chatsInSpotlight = false
    @AppStorage(AylaVoiceTextSetting.key) private var showsVoiceText = true
    @AppStorage(AppState.lockAfterKey) private var lockAfter = AppState.defaultLockAfter
    @Environment(AylaMemoryModel.self) private var memory

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

                    NavigationLink {
                        SignedInDevicesScreen()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(DevicesMessages.title)
                                    .textStyle(.listTitle)
                                    .foregroundStyle(Color.ink)
                                Text(DevicesMessages.settingsRowMessage)
                                    .textStyle(.caption)
                                    .foregroundStyle(Color.inkMuted)
                            }
                            Spacer(minLength: 0)
                            Image(.iconChevronRight)
                                .renderingMode(.template)
                                .foregroundStyle(Color.inkMuted)
                                .accessibilityHidden(true)
                        }
                        .padding(12)
                        .background(Color.white, in: .rect(cornerRadius: 14))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.pave)

                    Text("Ayla")
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.leading, 8)
                        .padding(.top, 20)
                        .accessibilityAddTraits(.isHeader)

                    NavigationLink {
                        AylaMemoryScreen()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wat Ayla over je weet")
                                    .textStyle(.listTitle)
                                    .foregroundStyle(Color.ink)
                                Text(memorySummary)
                                    .textStyle(.caption)
                                    .foregroundStyle(Color.inkMuted)
                            }
                            Spacer(minLength: 0)
                            Image(.iconChevronRight)
                                .renderingMode(.template)
                                .foregroundStyle(Color.inkMuted)
                                .accessibilityHidden(true)
                        }
                        .padding(12)
                        .background(Color.white, in: .rect(cornerRadius: 14))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.pave)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $showsVoiceText) {
                            Text("Tekst bij praten met Ayla")
                                .textStyle(.listTitle)
                                .foregroundStyle(Color.ink)
                        }
                        .tint(.brandGreen)
                        Text("Je leest zin voor zin mee met wat Ayla zegt. Zet je dit uit, dan zie je alleen de orb.")
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(12)
                    .background(Color.white, in: .rect(cornerRadius: 14))

                    Text("Privacy")
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.leading, 8)
                        .padding(.top, 20)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Opnieuw vergrendelen")
                                .textStyle(.listTitle)
                                .foregroundStyle(Color.ink)
                            Spacer(minLength: 8)
                            Picker("Opnieuw vergrendelen", selection: $lockAfter) {
                                Text("Meteen").tag(0)
                                Text("Na 1 minuut").tag(60)
                                Text("Na 5 minuten").tag(300)
                                Text("Na 15 minuten").tag(900)
                            }
                            .labelsHidden()
                            .tint(.brandGreen)
                        }
                        Text("Ben je even weg uit PAVE, dan vraagt de app daarna weer om je pincode of Face ID. In de appwisselaar zie je alleen het PAVE-logo.")
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(12)
                    .background(Color.white, in: .rect(cornerRadius: 14))

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

    private var memorySummary: String {
        switch memory.state {
        case .ready:
            guard memory.memories.isEnabled else { return "Uit: Ayla onthoudt niets" }
            let count = memory.notes.count
            return count == 0 ? "Ayla onthoudt nog niets" : count == 1 ? "Ayla onthoudt 1 ding" : "Ayla onthoudt \(count) dingen"
        case .notSetUp: return "Nog niet beschikbaar"
        default: return "Bekijk, pas aan of wis wat Ayla onthoudt"
        }
    }
}

#Preview {
    SettingsScreen(name: "Daaf", onShowMenu: {}, onSignOut: {})
        .environment(AylaMemoryModel(service: nil))
        .environment(SignedInDevicesModel(service: nil))
}
