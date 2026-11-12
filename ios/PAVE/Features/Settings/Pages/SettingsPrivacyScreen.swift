import SwiftUI

/// Instellingen › Privacy: when PAVE locks again, and whether your chats show up in the iPhone's search.
struct SettingsPrivacyScreen: View {
    @AppStorage(AylaSpotlight.settingKey) private var chatsInSpotlight = false
    @AppStorage(AppState.lockAfterKey) private var lockAfter = AppState.defaultLockAfter

    static func lockTitle(_ seconds: Int) -> String {
        switch seconds {
        case 0: "Meteen"
        case 60: "Na 1 minuut"
        case 300: "Na 5 minuten"
        default: "Na \(seconds / 60) minuten"
        }
    }

    var body: some View {
        SettingsPage(title: "Privacy") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Opnieuw vergrendelen")
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                    Spacer(minLength: 8)
                    Picker("Opnieuw vergrendelen", selection: $lockAfter) {
                        ForEach([0, 60, 300, 900], id: \.self) { seconds in
                            Text(Self.lockTitle(seconds)).tag(seconds)
                        }
                    }
                    .labelsHidden()
                    .tint(.paveAccent)
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
                .tint(.paveAccent)
                Text("De titels van je chats met Ayla komen in de zoekfunctie van je iPhone, zodat je een chat snel terugvindt. Alleen de titels, niet wat erin staat. Zet je dit uit of log je uit, dan haalt PAVE ze er meteen weer uit.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(12)
            .background(Color.white, in: .rect(cornerRadius: 14))
        }
    }
}
