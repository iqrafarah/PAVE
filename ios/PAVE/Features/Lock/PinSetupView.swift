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

    var body: some View {
        switch step {
        case .create:
            PinScreen(
                emblem: .iconShieldCheck,
                eyebrow: "Beveilig je account",
                title: "Kies een pincode",
                message: "Met deze pincode open je PAVE. Kies 6 cijfers die moeilijk te raden zijn."
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
                    .animation(.easeOut(duration: 0.2), value: errorMessage)
            }
        }
    }

    private func pad(keySize: CGFloat) -> some View {
        PinPad(digits: $digits, isError: errorMessage != nil, keySize: keySize, onComplete: submit)
            .disabled(isSubmitting)
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
            if let errorMessage {
                PaveInlineError(message: errorMessage)
            }
            PavePrimaryButton(title: "\(kind?.name ?? "Biometrie") gebruiken", loadingTitle: "Bezig met controleren...", isLoading: isSubmitting) {
                Task {
                    isSubmitting = true
                    defer { isSubmitting = false }
                    let didAuthenticate = await appState.authenticateForBiometricSetup()
                    finish(pin: pin, useBiometrics: didAuthenticate)
                }
            }
            AuthReturnButton(title: "Niet nu") {
                finish(pin: pin, useBiometrics: false)
            }
        }
    }

    private func submit(_ pin: String) {
        switch step {
        case .create:
            guard PinPolicy.isAcceptable(pin) else {
                fail("Kies een pincode die moeilijker te raden is, zonder herhaalde of oplopende cijfers.")
                return
            }
            reset(to: .confirm(first: pin))
        case .confirm(let first):
            guard pin == first else {
                fail("De pincodes zijn niet hetzelfde. Begin opnieuw.", then: .create)
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
        } catch {
            reset(to: .create)
            errorMessage = "We konden je pincode niet opslaan. Probeer het opnieuw."
        }
    }

    private func reset(to newStep: Step) {
        digits = ""
        errorMessage = nil
        step = newStep
    }

    private func fail(_ message: String, then next: Step? = nil) {
        errorMessage = message
        AccessibilityNotification.Announcement(message).post()
        isSubmitting = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            digits = ""
            isSubmitting = false
            if let next {
                step = next
                errorMessage = nil
            }
        }
    }
}

#Preview {
    PinSetupView()
        .environment(AppState(pinVault: PinVault(storage: InMemoryPinStorage())))
}
