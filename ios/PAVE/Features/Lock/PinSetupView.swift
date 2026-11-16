import PAVECore
import SwiftUI

struct PinSetupView: View {
    private enum Step: Equatable {
        case create
        case confirm(first: String)
        case biometrics(pin: String)
    }

    @Environment(AppState.self) private var appState
    @State private var step = Step.create
    @State private var digits = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var shakes = 0

    var body: some View {
        switch step {
        case .create:
            PinScreen(
                emblem: .iconShieldCheck,
                eyebrow: "Beveilig je account",
                title: "Kies een pincode",
                message: "Met deze pincode open je PAVE. Kies 6 cijfers, maar niet 111111 of 123456."
            ) { keySize in
                pad(keySize: keySize)
            } accessory: {
                PinErrorSlot(message: errorMessage)
                    .animation(.easeOut(duration: 0.2), value: errorMessage)
            }
        case .confirm:
            PinScreen(
                emblem: .iconShieldCheck,
                eyebrow: "Beveilig je account",
                title: "Herhaal je pincode",
                message: "Vul dezelfde 6 cijfers nog een keer in."
            ) { keySize in
                pad(keySize: keySize)
            } accessory: {
                VStack(spacing: 0) {
                    PinErrorSlot(message: errorMessage)
                    AuthReturnButton(title: "Opnieuw beginnen") { reset(to: .create) }
                }
                .animation(.easeOut(duration: 0.2), value: errorMessage)
            }
        case .biometrics(let pin):
            AuthScreen {
                biometricsIntro
            } content: {
                biometricsOffer(pin: pin)
            }
        }
    }

    private func pad(keySize: CGFloat) -> some View {
        PinPad(digits: $digits, isError: errorMessage != nil, keySize: keySize, onComplete: submit)
            .disabled(isSubmitting)
            .modifier(PinShake(trigger: shakes))
            // The message stays until you start on a new pincode, so you can read why the last one did not work.
            .onChange(of: digits) { _, newValue in
                if newValue.count == 1 { errorMessage = nil }
            }
    }

    private var biometricsIntro: some View {
        let name = appState.biometricKind?.name ?? "biometrie"
        return AuthIntro(
            eyebrow: "Snel ontgrendelen",
            title: "Ontgrendelen met \(name)",
            message: "Open PAVE met \(name) in plaats van je pincode. Je pincode blijft altijd werken."
        )
    }

    @ViewBuilder
    private func biometricsOffer(pin: String) -> some View {
        let kind = appState.biometricKind
        VStack(alignment: .leading, spacing: 24) {
            PavePrimaryButton(title: "\(kind?.name ?? "Biometrie") gebruiken", loadingTitle: "Bezig met controleren...", isLoading: isSubmitting) {
                Task {
                    isSubmitting = true
                    defer { isSubmitting = false }
                    let didAuthenticate = await appState.authenticateForBiometricSetup()
                    finish(pin: pin, useBiometrics: didAuthenticate)
                }
            }
            Button("Niet nu") { finish(pin: pin, useBiometrics: false) }
                .textStyle(.link)
                .foregroundStyle(Color.paveAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.pave)
        }
    }

    private func submit(_ pin: String) {
        switch step {
        case .create:
            guard PinPolicy.isAcceptable(pin) else {
                fail(PinMessages.tooEasy)
                return
            }
            reset(to: .confirm(first: pin))
        case .confirm(let first):
            guard pin == first else {
                fail(PinMessages.differ, then: .create)
                return
            }
            if appState.biometricKind != nil {
                reset(to: .biometrics(pin: pin))
            } else {
                finish(pin: pin, useBiometrics: false)
            }
        case .biometrics:
            break
        }
    }

    private func finish(pin: String, useBiometrics: Bool) {
        do {
            try appState.completePinSetup(pin: pin, useBiometrics: useBiometrics)
            PaveHaptics.success()
        } catch {
            reset(to: .create)
            errorMessage = PinMessages.notSaved
            PaveHaptics.error()
        }
    }

    private func reset(to newStep: Step) {
        digits = ""
        errorMessage = nil
        step = newStep
    }

    private func fail(_ message: String, then next: Step? = nil) {
        errorMessage = message
        shakes += 1
        AccessibilityNotification.Announcement(message).post()
        isSubmitting = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            digits = ""
            isSubmitting = false
            if let next {
                step = next
            }
        }
    }
}

#Preview {
    PinSetupView()
        .environment(AppState(pinVault: PinVault(storage: InMemoryPinStorage())))
}
