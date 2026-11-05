import PAVECore
import SwiftUI

struct SignInView: View {
    private enum Field {
        case email
        case password
    }

    @Environment(AuthFlow.self) private var flow
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var isShowingCredentials = true
    @State private var error: AuthError?
    @FocusState private var focus: Field?

    var body: some View {
        AuthScreen {
            VStack(alignment: .leading, spacing: 24) {
                AuthIntro(
                    eyebrow: "Sign in",
                    title: "Welcome to PAVE",
                    message: "Sign in to continue building your personal portfolio."
                )

                if let error {
                    errorNotice(for: error)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if isShowingCredentials {
                    fields
                }

                VStack(alignment: .leading, spacing: 12) {
                    PavePrimaryButton(title: "Sign in", loadingTitle: "Signing in…", isLoading: isSubmitting, action: submit)
                    if isSubmitting {
                        Text("Checking your details securely. Please wait — this may take a moment.")
                            .textStyle(.footnote)
                            .foregroundStyle(Color.inkMuted)
                    }
                }

                guidance
            }
            .animation(.easeOut(duration: 0.2), value: error)
            .animation(.easeOut(duration: 0.2), value: isSubmitting)
        }
        .onAppear {
            password = ""
            isShowingCredentials = true
        }
        .onDisappear {
            isShowingCredentials = false
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaveTextField(
                label: "Email address",
                placeholder: "Your organization email",
                text: $email,
                kind: .email,
                focus: $focus,
                field: .email
            )
            .submitLabel(.next)
            .onSubmit { focus = .password }

            PaveTextField(
                label: "Password",
                placeholder: "Enter your password",
                text: $password,
                kind: .password,
                focus: $focus,
                field: .password
            )
            .submitLabel(.go)
            .onSubmit(submit)

            Button("Forgot password?", action: flow.showForgotPassword)
                .textStyle(.link)
                .foregroundStyle(isSubmitting ? Color.inkMuted : .brandGreen)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                .buttonStyle(.plain)
        }
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.62 : 1)
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                Image(.iconShieldCheck)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text("Two-step verification is required. After your password, enter a code from your authenticator app.")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            PaveNotice(
                title: "Your account is provided",
                message: "Use the account supplied by your organization. If you don’t have your details, contact IT support."
            )
        }
    }

    @ViewBuilder
    private func errorNotice(for error: AuthError) -> some View {
        if error == .invalidCredentials {
            PaveNotice(
                title: "We couldn’t sign you in",
                message: "Your email or password is incorrect. Check your details and try again, or reset your password below.",
                tone: .critical
            )
        } else if error == .accountNotActive {
            PaveNotice(
                title: "Your account isn’t active yet",
                message: "Your account hasn’t been confirmed or has been paused. Contact your organization’s IT support.",
                tone: .critical
            )
        } else {
            PaveNotice(
                title: "Something went wrong",
                message: "We couldn’t reach PAVE. Check your internet connection and try again.",
                tone: .critical
            )
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        focus = nil
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.signIn(email: email, password: password)
                error = nil
            } catch {
                self.error = AuthError(error)
            }
        }
    }
}

#Preview {
    AuthFlowView(service: MockAuthService()) { _ in }
}
