import PAVECore
import SwiftUI

struct PinLockView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var digits = ""
    @State private var errorMessage: String?
    @State private var shakes = 0
    @State private var isChecking = false
    @State private var showsForgotPin = false
    @State private var didOfferBiometrics = false

    var body: some View {
        PinScreen(
            emblem: .iconShieldCheck,
            eyebrow: "Welcome back",
            title: "Enter your PIN",
            message: "Enter your 6-digit PIN to open PAVE."
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
            .modifier(Shake(trigger: shakes, isEnabled: !reduceMotion))
        } accessory: {
            VStack(spacing: 0) {
                PinErrorSlot(message: errorMessage)
                Button("Forgot PIN?") { showsForgotPin = true }
                    .textStyle(.link)
                    .foregroundStyle(Color.brandGreen)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.plain)
            }
            .animation(.easeOut(duration: 0.2), value: errorMessage)
        }
        .confirmationDialog("Forgot your PIN?", isPresented: $showsForgotPin, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { appState.forgetPin() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll be signed out. Sign in again with your password and verification code, then create a new PIN.")
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
            let message = remaining == 1 ? "Incorrect PIN. 1 attempt left." : "Incorrect PIN. \(remaining) attempts left."
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

private struct Shake: ViewModifier {
    let trigger: Int
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
                view.offset(x: isEnabled ? offset : 0)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: 0.01)
                    LinearKeyframe(-12, duration: 0.07)
                    LinearKeyframe(12, duration: 0.07)
                    LinearKeyframe(-8, duration: 0.07)
                    LinearKeyframe(8, duration: 0.07)
                    LinearKeyframe(0, duration: 0.07)
                }
            }
            .sensoryFeedback(.error, trigger: trigger)
    }
}

#Preview {
    PinLockView()
        .environment(AppState(pinVault: PinVault(storage: InMemoryPinStorage())))
}
