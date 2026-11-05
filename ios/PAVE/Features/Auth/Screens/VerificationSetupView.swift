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
            VStack(alignment: .leading, spacing: 24) {
                AuthIntro(
                    eyebrow: "First-time setup",
                    title: "Protect your PAVE account",
                    message: "Two-step verification is mandatory to keep your personal information, achievements and certificates safe."
                )

                if setupFailed {
                    PaveNotice(
                        title: "We couldn’t start the setup",
                        message: "Go back to login and sign in again. If this keeps happening, contact IT support.",
                        tone: .critical
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    SetupStepRow(
                        number: 1,
                        title: "Add PAVE to your codes",
                        message: "Your \(deviceName) can create the 6-digit code for you. In Passwords, choose the PAVE login you just saved, or add a new one."
                    )
                    addToThisDevice
                    SetupStepRow(
                        number: 2,
                        title: "Enter the code",
                        message: "Come back here and enter the 6-digit code. Your \(deviceName) may suggest it above the keyboard."
                    )
                }

                VerificationCodeField(code: $code, errorMessage: errorMessage, isFocused: $isCodeFocused)
                    .onChange(of: code) { error = nil }

                PavePrimaryButton(
                    title: "Confirm setup",
                    loadingTitle: "Confirming…",
                    isLoading: isSubmitting,
                    action: submit
                )

                if let setupURI = enrollment?.setupURI {
                    otherDevice(setupURI: setupURI)
                }

                Text("Can’t set up two-step verification? Contact your organization’s IT support for help.")
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
            PaveSecondaryButton(title: "Set up on this \(deviceName)", icon: .iconShieldCheck) {
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
                    title: "No app found to store the code",
                    message: "Use the setup key or another device below, or install an authenticator app first.",
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
                    Text("Use another device instead")
                        .textStyle(.link)
                        .foregroundStyle(Color.brandGreen)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.brandGreen)
                        .rotationEffect(.degrees(showsOtherDevice ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(showsOtherDevice ? "Expanded" : "Collapsed")

            if showsOtherDevice {
                OtherDeviceSetupCard(setupURI: setupURI, secret: enrollment?.secret)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var deviceName: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }

    private var errorMessage: String? {
        switch error {
        case nil: nil
        case .invalidCode: "This code is invalid or has expired. Use the latest code and try again."
        default: "We couldn’t finish the setup. Check your internet connection and try again."
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isCodeFocused = false
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.confirmVerificationSetup(code: code)
            } catch {
                self.error = AuthError(error)
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
