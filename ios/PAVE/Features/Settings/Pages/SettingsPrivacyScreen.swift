import SwiftUI

/// Instellingen › Privacy: when PAVE locks again, whether your chats show up in the iPhone's search, and the account PIN
/// of the locked chats (change it, or reset it with the authenticator app).
struct SettingsPrivacyScreen: View {
    @AppStorage(AylaSpotlight.settingKey) private var chatsInSpotlight = false
    @AppStorage(AppState.lockAfterKey) private var lockAfter = AppState.defaultLockAfter
    @Environment(AylaChatModel.self) private var chats: AylaChatModel?
    @State private var hasPin: Bool?
    @State private var pinSheet: AylaAccountPinSheet.Purpose?
    @State private var pinNotice: String?
    @State private var pinCheckFailed = false

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
            .background(Color.panel, in: .rect(cornerRadius: 14))

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
            .background(Color.panel, in: .rect(cornerRadius: 14))

            if chats?.conversationList.canLock == true {
                accountPinCard
            }
        }
        .task {
            guard hasPin == nil, let chats else { return }
            hasPin = await chats.chatPinExists()
            pinCheckFailed = hasPin == nil
        }
        .alert("Dat lukte niet", isPresented: Binding(get: { chats?.chatsProblem != nil && pinSheet == nil }, set: { if !$0 { chats?.chatsProblem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(chats?.chatsProblem ?? "")
        }
        .sheet(item: $pinSheet) { purpose in
            if let chats {
                AylaAccountPinSheet(purpose: purpose, model: chats) { message in
                    pinNotice = message
                    Task { hasPin = await chats.chatPinExists() }
                }
                .paveSheet()
            }
        }
        .alert(pinNotice ?? "", isPresented: Binding(get: { pinNotice != nil }, set: { if !$0 { pinNotice = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    /// Accountpincode: the same PIN on every device, so it is changed or reset here as well as on the web.
    private var accountPinCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AylaMessages.accountPinTitle)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                Text(hasPin == false ? AylaMessages.accountPinNone : AylaMessages.accountPinIntro)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if hasPin == true {
                Divider()
                pinRow(AylaMessages.accountPinChangeTitle, AylaMessages.accountPinChangeBody, AylaMessages.accountPinChangeButton, isDanger: false) {
                    pinSheet = .change
                }
                Divider()
                pinRow(AylaMessages.accountPinResetTitle, AylaMessages.accountPinResetBody, AylaMessages.accountPinResetButton, isDanger: true) {
                    pinSheet = .recover
                }
            } else if pinCheckFailed {
                PaveInlineError(message: AylaMessages.pinCheckFailed)
            }
        }
        .padding(12)
        .background(Color.panel, in: .rect(cornerRadius: 14))
    }

    /// The text beside the button where there is room, the button under it where there is not.
    private func pinRow(_ title: String, _ body: String, _ button: String, isDanger: Bool, action: @escaping () -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                pinText(title, body)
                Spacer(minLength: 8)
                pinButton(button, title, isDanger, action)
            }
            VStack(alignment: .leading, spacing: 8) {
                pinText(title, body)
                pinButton(button, title, isDanger, action)
            }
        }
    }

    private func pinText(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
            Text(body)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 360, alignment: .leading)
    }

    /// Resetten is in red, as on the web: it is for when you forgot the PIN.
    private func pinButton(_ title: String, _ label: String, _ isDanger: Bool, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .textStyle(.link)
            .foregroundStyle(isDanger ? Color.critical : Color.paveAccent)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(isDanger ? Color.criticalSurface : Color.paveSurfaceTint, in: .capsule)
            .buttonStyle(.pave)
            .accessibilityLabel(label)
    }
}