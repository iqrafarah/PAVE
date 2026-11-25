import SwiftUI

/// The PIN in front of a locked e-mail conversation: the same PIN as for locked chats, checked by PAVE's server. Without
/// a PIN yet, you choose one first.
struct EmailLockGate: View {
    /// Locking a conversation for the first time: choose a PIN, and then it locks.
    enum Purpose { case open, lock }

    var purpose = Purpose.open
    var onDone: () -> Void

    @Environment(EmailModel.self) private var email
    @Environment(AylaChatModel.self) private var ayla: AylaChatModel?
    @State private var hasPin: Bool?
    @State private var checkFailed = false
    @State private var recovers = false
    @State private var notice: String?

    var body: some View {
        Group {
            if let ayla, hasPin == false {
                AylaChatPinView(mode: .create, subtitle: "Kies 4 cijfers. Daarmee open je je vergrendelde chats en e-mails.") { pin in
                    let failure = await ayla.setChatPin(pin)
                    if failure == nil { finish() }
                    return failure
                }
            } else if let ayla, hasPin == true {
                if purpose == .lock {
                    // There is a PIN already: locking needs nothing more.
                    Color.clear.onAppear(perform: onDone)
                } else {
                    AylaChatPinView(mode: .enter, subtitle: "Typ je pincode om dit gesprek te openen.") { pin in
                        let failure = await ayla.verifyChatPin(pin)
                        if failure == nil { finish() }
                        return failure
                    } onForgot: {
                        recovers = true
                    }
                }
            } else if ayla == nil || checkFailed {
                VStack(spacing: 12) {
                    PaveInlineError(message: AylaMessages.pinCheckFailed)
                    Button("Opnieuw proberen") { Task { await check() } }
                        .textStyle(.link)
                        .foregroundStyle(Color.paveAccent)
                        .frame(minHeight: 44)
                }
                .padding(24)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas.ignoresSafeArea())
        .task { if hasPin == nil { await check() } }
        .sheet(isPresented: $recovers) {
            if let ayla {
                AylaAccountPinSheet(purpose: .recover, model: ayla) { message in notice = message }
                    .paveSheet()
            }
        }
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func check() async {
        checkFailed = false
        guard let ayla else { return }
        if let exists = await ayla.chatPinExists() {
            hasPin = exists
        } else {
            checkFailed = true
        }
    }

    private func finish() {
        email.showsLocked = true
        PaveHaptics.success()
        onDone()
    }
}
