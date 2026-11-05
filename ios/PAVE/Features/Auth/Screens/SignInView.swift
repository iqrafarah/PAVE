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
                    eyebrow: "Inloggen",
                    title: "Welkom bij PAVE",
                    message: "Log in om verder te werken aan je persoonlijke portfolio."
                )

                if let error {
                    errorNotice(for: error)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if isShowingCredentials {
                    fields
                }

                VStack(alignment: .leading, spacing: 12) {
                    PavePrimaryButton(title: "Inloggen", loadingTitle: "Inloggen…", isLoading: isSubmitting, action: submit)
                    if isSubmitting {
                        Text("We controleren je gegevens veilig. Een moment geduld.")
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
                label: "E-mailadres",
                placeholder: "E-mailadres van je organisatie",
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
                Text("Tweestapsverificatie is verplicht. Na je wachtwoord vul je een code in uit je authenticator-app.")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            PaveNotice(
                title: "Je account krijg je van je organisatie",
                message: "Gebruik het account dat je van je organisatie hebt gekregen. Heb je je gegevens niet? Neem contact op met de IT-support."
            )
        }
    }

    @ViewBuilder
    private func errorNotice(for error: AuthError) -> some View {
        if error == .invalidCredentials {
            PaveNotice(
                title: "Inloggen is niet gelukt",
                message: "Je e-mailadres of wachtwoord klopt niet. Controleer je gegevens en probeer het opnieuw, of stel hieronder een nieuw wachtwoord in.",
                tone: .critical
            )
        } else if error == .accountNotActive {
            PaveNotice(
                title: "Je account is nog niet actief",
                message: "Je account is nog niet bevestigd of tijdelijk geblokkeerd. Neem contact op met de IT-support van je organisatie.",
                tone: .critical
            )
        } else {
            PaveNotice(
                title: "Er ging iets mis",
                message: "We konden PAVE niet bereiken. Controleer je internetverbinding en probeer het opnieuw.",
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
