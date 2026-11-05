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
                message: "Vul het e-mailadres van je organisatie in. We sturen je een link om een nieuw wachtwoord in te stellen."
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
                    errorMessage: error == nil ? nil : "We konden de link niet versturen. Controleer je internetverbinding en probeer het opnieuw."
                )
                .submitLabel(.send)
                .onSubmit(submit)
                .disabled(isSubmitting)

                PavePrimaryButton(title: "Link versturen", loadingTitle: "Versturen…", isLoading: isSubmitting, action: submit)

                Text("Gebruik het e-mailadres van het PAVE-account dat je van je organisatie hebt gekregen.")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)

                AuthReturnButton(action: flow.returnToLogin)
            }
        }
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

struct ResetEmailSentView: View {
    let email: String

    @Environment(AuthFlow.self) private var flow
    @State private var isSubmitting = false
    @State private var error: AuthError?

    var body: some View {
        AuthScreen {
            AuthIntro(
                emblem: .iconMailOpen,
                eyebrow: "Wachtwoord herstellen",
                title: "Kijk in je inbox",
                message: "Als er een account bestaat voor \(email), sturen we een link om een nieuw wachtwoord in te stellen."
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                if error == nil {
                    PaveNotice(
                        title: "Geen e-mail ontvangen?",
                        message: "Wacht een paar minuten en kijk in je map met spam of ongewenste e-mail. Nog niets? Vraag een nieuwe link aan."
                    )
                } else {
                    PaveNotice(
                        title: "We konden geen nieuwe link versturen",
                        message: "Controleer je internetverbinding en probeer het opnieuw.",
                        tone: .critical
                    )
                }

                PavePrimaryButton(title: "Link opnieuw versturen", loadingTitle: "Versturen…", isLoading: isSubmitting, action: resend)

                Text("Voor je privacy laten we niet weten of een e-mailadres een PAVE-account heeft.")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)

                AuthReturnButton(action: flow.returnToLogin)
            }
        }
    }

    private func resend() {
        guard !isSubmitting else { return }
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.requestPasswordReset(email: email)
                error = nil
            } catch {
                self.error = AuthError(error)
            }
        }
    }
}

#Preview("Wachtwoord vergeten") {
    NavigationStack {
        ForgotPasswordView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}

#Preview("E-mail verstuurd") {
    NavigationStack {
        ResetEmailSentView(email: "ravi@student.example.edu")
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
