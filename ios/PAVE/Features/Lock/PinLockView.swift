import PAVECore
import SwiftUI

struct PinLockView: View {
    @Environment(AppState.self) private var appState
    @State private var digits = ""
    @State private var errorMessage: String?
    @State private var shakes = 0
    @State private var isChecking = false
    @State private var showsForgotPin = false
    @State private var didOfferBiometrics = false

    var body: some View {
        PinScreen(
            emblem: .iconShieldCheck,
            eyebrow: "Welkom terug",
            title: "Vul je pincode in",
            message: "Vul je pincode van 6 cijfers in om PAVE te openen."
        ) { keySize in
            PinPad(
                digits: $digits,
                isError: errorMessage != nil,
                keySize: keySize,
                biometricKind: appState.canUnlockWithBiometrics ? appState.biometricKind : nil,
                onBiometric: unlockWithBiometrics,
                onComplete: check
            )
            .disabled(isChecking)
            .modifier(PinShake(trigger: shakes))
        } accessory: {
            VStack(spacing: 0) {
                PinErrorSlot(message: errorMessage)
                Button("Pincode vergeten?") { showsForgotPin = true }
                    .textStyle(.link)
                    .foregroundStyle(Color.brandGreen)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.pave)
            }
            .animation(.easeOut(duration: 0.2), value: errorMessage)
        }
        .confirmationDialog("Pincode vergeten?", isPresented: $showsForgotPin, titleVisibility: .visible) {
            Button("Uitloggen", role: .destructive) { appState.forgetPin() }
            Button("Annuleer", role: .cancel) {}
        } message: {
            Text("Je wordt uitgelogd. Log opnieuw in met je wachtwoord en verificatiecode en kies daarna een nieuwe pincode.")
        }
        .task {
            guard !didOfferBiometrics else { return }
            didOfferBiometrics = true
            await appState.unlockWithBiometrics()
        }
    }

    private func check(_ pin: String) {
        let result = appState.unlock(with: pin)
        switch result {
        case .correct, .lockedOut:
            break
        case .incorrect(let remaining):
            let message = PinMessages.incorrect(attemptsRemaining: remaining)
            errorMessage = message
            shakes += 1
            AccessibilityNotification.Announcement(message).post()
            isChecking = true
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                digits = ""
                isChecking = false
            }
        }
    }

    private func unlockWithBiometrics() {
        Task { await appState.unlockWithBiometrics() }
    }
}

#Preview {
    PinLockView()
        .environment(AppState(pinVault: PinVault(storage: InMemoryPinStorage())))
}
