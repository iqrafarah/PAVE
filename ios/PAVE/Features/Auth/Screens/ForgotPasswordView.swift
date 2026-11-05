import PAVECore
import SwiftUI

struct ForgotPasswordView: View {
    private enum Field {
        case email
    }

    @Environment(AuthFlow.self) private var flow
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var error: AuthError?
    @FocusState private var focus: Field?

    var body: some View {
        AuthScreen {
            AuthIntro(
                emblem: .iconMail,
                eyebrow: "Wachtwoord herstellen",
                title: "Wachtwoord vergeten?",
                message: "Vul het e-mailadres van je organisatie in. We sturen je een code om je wachtwoord te herstellen."
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                PaveTextField(
                    label: "E-mailadres",
                    placeholder: "E-mailadres van je organisatie",
                    text: $email,
                    kind: .email,
                    focus: $focus,
                    field: .email,
                    errorMessage: sendErrorMessage
                )
                .submitLabel(.send)
                .onSubmit(submit)
                .disabled(isSubmitting)

                PavePrimaryButton(title: "Code versturen", loadingTitle: "Versturen…", isLoading: isSubmitting, action: submit)

                Text("Gebruik het e-mailadres van het PAVE-account dat je van je organisatie hebt gekregen.")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)

                AuthReturnButton(action: flow.returnToLogin)
            }
        }
    }

    private var sendErrorMessage: String? {
        guard let error else { return nil }
        return error == .rateLimited
            ? "Je hebt net al een code aangevraagd. Wacht 60 seconden en probeer het opnieuw."
            : "We konden de code niet versturen. Probeer het later opnieuw of neem contact op met de IT-support."
    }

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            focus = .email
            return
        }
        guard !isSubmitting else { return }
        focus = nil
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.requestPasswordReset(email: trimmedEmail)
                error = nil
            } catch {
                self.error = AuthError(error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
