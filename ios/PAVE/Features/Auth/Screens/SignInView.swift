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
            AuthIntro(
                title: "Welkom bij PAVE",
                message: AuthMessages.loginInstruction
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                if isShowingCredentials {
                    fields
                }

                PavePrimaryButton(title: "Inloggen", loadingTitle: "Bezig met inloggen...", isLoading: isSubmitting, action: submit)

                supportOrError
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
    }

    private var supportOrError: some View {
        ZStack(alignment: .topLeading) {
            Group {
                supportLine
                ForEach(AuthError.allMessages, id: \.self) { PaveNotice(message: $0, tone: .critical) }
            }
            .hidden()
            .accessibilityHidden(true)

            if let error {
                PaveNotice(message: error.message, tone: .critical)
                    .transition(.opacity)
            } else {
                supportLine
                    .transition(.opacity)
            }
        }
    }

    private var supportLine: some View {
        Text(SupportText.sentence("Heb je geen account of lukt inloggen niet? Mail naar "))
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
