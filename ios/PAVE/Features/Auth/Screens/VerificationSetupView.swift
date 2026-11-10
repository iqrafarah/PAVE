import PAVECore
import SwiftUI

struct VerificationSetupView: View {
    @Environment(AuthFlow.self) private var flow
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var code = ""
    @State private var isSubmitting = false
    @State private var error: AuthError?
    @State private var setupFailed = false
    @State private var enrollment: VerificationEnrollment?
    @State private var isPreparing = true
    @State private var didOpenAuthenticator = false
    @State private var noAuthenticatorFound = false
    @State private var showsOtherDevice = false
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        AuthScreen {
            AuthIntro(
                eyebrow: "Eerste keer instellen",
                title: "Beveilig je PAVE-account",
                message: AuthMessages.verificationSetupInstruction
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    SetupStepRow(
                        number: 1,
                        title: "Voeg PAVE toe aan je codes",
                        message: "Je toestel kan de code van 6 cijfers voor je maken. Kies in Wachtwoorden je PAVE-inlog, of voeg een nieuwe toe."
                    )
                    addToThisDevice
                    SetupStepRow(
                        number: 2,
                        title: "Vul de code in",
                        message: "Kom terug naar PAVE en vul de code van 6 cijfers in. Je toestel stelt hem misschien boven het toetsenbord voor."
                    )
                }

                VerificationCodeField(
                    code: $code,
                    title: AuthMessages.authenticatorCodeLabel,
                    errorMessage: errorMessage,
                    reservedErrors: [AuthMessages.setupCouldNotStart] + AuthError.allMessages,
                    isFocused: $isCodeFocused
                )
                    .onChange(of: code) { error = nil }

                PavePrimaryButton(
                    title: "Instellen bevestigen",
                    loadingTitle: "Bezig met bevestigen...",
                    isLoading: isSubmitting,
                    action: submit
                )

                if let setupURI = enrollment?.setupURI {
                    otherDevice(setupURI: setupURI)
                }

                Text(SupportText.sentence("Lukt het instellen niet? Neem contact op via "))
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)

                AuthReturnButton(action: flow.returnToLogin)
            }
            .animation(.easeOut(duration: 0.2), value: showsOtherDevice)
            .animation(.easeOut(duration: 0.2), value: noAuthenticatorFound)
        }
        .task {
            defer { isPreparing = false }
            do {
                enrollment = try await flow.startVerificationSetup()
            } catch {
                setupFailed = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && didOpenAuthenticator {
                isCodeFocused = true
            }
        }
    }

    @ViewBuilder
    private var addToThisDevice: some View {
        if let setupURI = enrollment?.setupURI {
            PaveSecondaryButton(title: "Instellen op dit toestel", icon: .iconShieldCheck) {
                openURL(setupURI) { accepted in
                    didOpenAuthenticator = accepted
                    noAuthenticatorFound = !accepted
                    if !accepted {
                        showsOtherDevice = true
                    }
                }
            }
            if noAuthenticatorFound {
                PaveNotice(
                    title: "Geen app gevonden voor de code",
                    message: "Gebruik hieronder de instelsleutel of een ander apparaat, of installeer eerst een authenticator-app.",
                    tone: .critical
                )
            }
        } else {
            SetupPreviewPlaceholder(isLoading: isPreparing)
        }
    }

    private func otherDevice(setupURI: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showsOtherDevice.toggle()
            } label: {
                HStack {
                    Text("Een ander apparaat gebruiken")
                        .textStyle(.link)
                        .foregroundStyle(Color.brandGreen)
                    Spacer()
                    Image(.iconChevronDown)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.brandGreen)
                        .rotationEffect(.degrees(showsOtherDevice ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityValue(showsOtherDevice ? "Uitgeklapt" : "Ingeklapt")

            if showsOtherDevice {
                OtherDeviceSetupCard(setupURI: setupURI, secret: enrollment?.secret)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var errorMessage: String? {
        error?.message ?? (setupFailed ? AuthMessages.setupCouldNotStart : nil)
    }

    private func submit() {
        guard !isSubmitting else { return }
        isCodeFocused = false
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.confirmVerificationSetup(code: code)
                PaveHaptics.success()
            } catch {
                self.error = AuthError(error)
                PaveHaptics.error()
            }
        }
    }
}

#Preview {
    NavigationStack {
        VerificationSetupView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
