import PAVECore
import SwiftUI

struct NewPasswordView: View {
    private enum Field {
        case password
        case confirmation
    }

    @Environment(AuthFlow.self) private var flow
    @State private var password = ""
    @State private var confirmation = ""
    @State private var passwordError: String?
    @State private var confirmationError: String?
    @State private var isSubmitting = false
    @FocusState private var focus: Field?

    var body: some View {
        AuthScreen {
            AuthIntro(
                eyebrow: "Wachtwoord herstellen",
                title: "Kies een nieuw wachtwoord",
                message: "Kies een sterk wachtwoord dat je nergens anders gebruikt."
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                PaveTextField(
                    label: "Nieuw wachtwoord",
                    placeholder: "Vul een nieuw wachtwoord in",
                    text: $password,
                    kind: .newPassword,
                    focus: $focus,
                    field: .password,
                    errorMessage: passwordError
                )
                .submitLabel(.next)
                .onSubmit { focus = .confirmation }
                .onChange(of: password) { passwordError = nil }

                PasswordRequirementsList(password: password)

                PaveTextField(
                    label: "Herhaal je nieuwe wachtwoord",
                    placeholder: "Vul je nieuwe wachtwoord nog een keer in",
                    text: $confirmation,
                    kind: .newPassword,
                    focus: $focus,
                    field: .confirmation,
                    errorMessage: confirmationError
                )
                .submitLabel(.done)
                .onSubmit(submit)
                .onChange(of: confirmation) { confirmationError = nil }

                PavePrimaryButton(title: "Wachtwoord opslaan", loadingTitle: "Opslaan…", isLoading: isSubmitting, action: submit)

                AuthReturnButton(action: flow.returnToLogin)
            }
            .disabled(isSubmitting)
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        guard PasswordRequirement.allMet(by: password) else {
            passwordError = "Je wachtwoord voldoet nog niet aan alle eisen."
            focus = .password
            return
        }
        guard password == confirmation else {
            confirmationError = "De wachtwoorden zijn niet hetzelfde. Vul je nieuwe wachtwoord opnieuw in."
            focus = .confirmation
            return
        }
        focus = nil
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.updatePassword(password)
            } catch {
                passwordError = switch AuthError(error) {
                case .weakPassword: "Je wachtwoord voldoet nog niet aan alle eisen."
                case .samePassword: "Kies een wachtwoord dat anders is dan je huidige wachtwoord."
                case .resetSessionExpired: "Je herstelsessie is verlopen. Ga terug naar inloggen en vraag een nieuwe code aan."
                case .insufficientAssurance: "Bevestig eerst de code uit je authenticator-app. Ga terug naar inloggen en vraag een nieuwe code aan."
                default: "We konden je wachtwoord niet opslaan. Controleer je internetverbinding en probeer het opnieuw."
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NewPasswordView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
