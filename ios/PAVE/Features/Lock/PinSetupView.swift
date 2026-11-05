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
                eyebrow: "Secure your account",
                title: "Create a PIN",
                message: "You’ll use this PIN to open PAVE. Choose 6 digits that are hard to guess."
            ) { keySize in
                pad(keySize: keySize)
            } accessory: {
                PinErrorSlot(message: errorMessage)
                    .animation(.easeOut(duration: 0.2), value: errorMessage)
            }
        case .confirm:
            PinScreen(
                emblem: .iconShieldCheck,
                eyebrow: "Secure your account",
                title: "Confirm your PIN",
                message: "Enter the same 6 digits once more."
            ) { keySize in
                pad(keySize: keySize)
            } accessory: {
                VStack(spacing: 0) {
                    PinErrorSlot(message: errorMessage)
                    AuthReturnButton(title: "Start over") { reset(to: .create) }
                }
                .animation(.easeOut(duration: 0.2), value: errorMessage)
            }
        case .biometrics(let pin):
            AuthScreen {
                biometricsOffer(pin: pin)
                    .animation(.easeOut(duration: 0.2), value: errorMessage)
            }
        }
    }

    private func pad(keySize: CGFloat) -> some View {
        PinPad(digits: $digits, isError: errorMessage != nil, keySize: keySize, onComplete: submit)
            .disabled(isSubmitting)
    }

    @ViewBuilder
    private func biometricsOffer(pin: String) -> some View {
        let kind = appState.biometricKind
        VStack(alignment: .leading, spacing: 24) {
            AuthIntro(
                eyebrow: "Quick unlock",
                title: "Unlock with \(kind?.name ?? "biometrics")",
                message: "Open PAVE with \(kind?.name ?? "biometrics") instead of typing your PIN. You can always use your PIN."
            )
            if let errorMessage {
                PaveInlineError(message: errorMessage)
            }
            PavePrimaryButton(title: "Use \(kind?.name ?? "biometrics")", loadingTitle: "Checking…", isLoading: isSubmitting) {
                Task {
                    isSubmitting = true
                    defer { isSubmitting = false }
                    let didAuthenticate = await appState.authenticateForBiometricSetup()
                    finish(pin: pin, useBiometrics: didAuthenticate)
                }
            }
            AuthReturnButton(title: "Not now") {
                finish(pin: pin, useBiometrics: false)
            }
        }
    }

    private func submit(_ pin: String) {
        switch step {
        case .create:
            guard PinPolicy.isAcceptable(pin) else {
                fail("Choose a PIN that’s harder to guess, without repeated or consecutive digits.")
                return
            }
            reset(to: .confirm(first: pin))
        case .confirm(let first):
            guard pin == first else {
                fail("The PINs don’t match. Start again.", then: .create)
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
            errorMessage = "We couldn’t save your PIN. Try again."
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
