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
    @State private var isResending = false
    @FocusState private var focus: Field?

    var body: some View {
        AuthScreen {
            AuthIntro(
                title: "Inloggen met eduID",
                message: AuthMessages.loginInstruction
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                if isShowingCredentials {
                    fields
                }

                PavePrimaryButton(title: "Inloggen", loadingTitle: "Bezig met inloggen...", isLoading: isSubmitting, action: submit)

                helpOrError

                accountLine
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
                label: "E-mailadres",
                placeholder: "E-mailadres",
                text: $email,
                kind: .email,
                focus: $focus,
                field: .email
            )
            .submitLabel(.next)
            .onSubmit { focus = .password }

            PaveTextField(
                label: "Wachtwoord",
                placeholder: "Vul je wachtwoord in",
                text: $password,
                kind: .password,
                focus: $focus,
                field: .password
            )
            .submitLabel(.go)
            .onSubmit(submit)

            Button("Wachtwoord vergeten?", action: flow.showForgotPassword)
                .textStyle(.link)
                .foregroundStyle(isSubmitting ? Color.inkMuted : .paveAccent)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                .buttonStyle(.pave)
        }
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.62 : 1)
        .onChange(of: email) { if error != .emailNotConfirmed { error = nil } }
        .onChange(of: password) { if error != .emailNotConfirmed { error = nil } }
    }

    /// An error takes the place of "Lukt inloggen niet?", in room that is kept for it, so nothing moves; "Account
    /// aanmaken" always stays under it.
    private var helpOrError: some View {
        ZStack(alignment: .topLeading) {
            Group {
                helpLine
                ForEach(AuthError.allMessages, id: \.self) { PaveNotice(message: $0, tone: .critical) }
                unconfirmedNotice
            }
            .hidden()
            .accessibilityHidden(true)

            if error == .emailNotConfirmed {
                unconfirmedNotice
                    .transition(.opacity)
            } else if let error {
                PaveNotice(message: error.message, tone: .critical)
                    .transition(.opacity)
            } else {
                helpLine
                    .transition(.opacity)
            }
        }
    }

    /// An account made here whose e-mail code was never typed: a new code, and on to typing it.
    private var unconfirmedNotice: some View {
        VStack(alignment: .leading, spacing: 4) {
            PaveNotice(message: AuthMessages.emailNotConfirmed, tone: .critical)
            Button(action: resendConfirmation) {
                Text(isResending ? "Bezig met versturen..." : "Bevestigingsmail opnieuw versturen")
                    .textStyle(.link)
                    .underline()
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .disabled(isResending)
        }
    }

    private func resendConfirmation() {
        guard !isResending else { return }
        Task {
            isResending = true
            defer { isResending = false }
            do {
                try await flow.resendSignUpCode(email: email)
                error = nil
                flow.showSignUpCode(email: email)
            } catch {
                self.error = AuthError(error)
                PaveHaptics.error()
            }
        }
    }

    private var accountLine: some View {
        HStack(spacing: 4) {
            Text("Nog geen eduID?")
                .textStyle(.footnote)
                .foregroundStyle(Color.inkMuted)
            Button(action: flow.showRegister) {
                Text("Account aanmaken")
                    .textStyle(.link)
                    .underline()
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .disabled(isSubmitting)
        }
    }

    private var helpLine: some View {
        Text(SupportText.sentence("Lukt inloggen niet? Mail naar "))
            .textStyle(.footnote)
            .foregroundStyle(Color.inkMuted)
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
                PaveHaptics.error()
            }
        }
    }
}

#Preview {
    AuthFlowView(service: MockAuthService()) { _ in }
}
