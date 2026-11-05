import PAVECore
import SwiftUI

struct VerificationSetupCompleteView: View {
    @Environment(AuthFlow.self) private var flow

    var body: some View {
        AuthScreen {
            AuthIntro(
                emblem: .iconCheckCircle,
                eyebrow: "Instellen gelukt",
                title: "Je bent klaar",
                message: "Tweestapsverificatie staat nu aan voor je PAVE-account."
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                PaveNotice(
                    title: "Je portfolio is extra beveiligd",
                    message: "Log je de volgende keer in, gebruik dan je wachtwoord en een code uit je authenticator-app. Houd de app op je telefoon."
                )
                PavePrimaryButton(title: "Verder naar PAVE", action: flow.finishVerificationSetup)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

struct PasswordResetCompleteView: View {
    @Environment(AuthFlow.self) private var flow

    var body: some View {
        AuthScreen {
            AuthIntro(
                emblem: .iconCheckCircle,
                eyebrow: "Wachtwoord hersteld",
                title: "Wachtwoord gewijzigd",
                message: "Je nieuwe wachtwoord is opgeslagen. Je kunt er nu mee inloggen bij PAVE."
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                PaveNotice(
                    title: "Tweestapsverificatie staat nog steeds aan",
                    message: "Je extra beveiliging blijft gewoon staan. Houd je authenticator-app bij de hand als je inlogt."
                )
                PavePrimaryButton(title: "Terug naar inloggen", action: flow.returnToLogin)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

#Preview("Instellen gelukt") {
    NavigationStack {
        VerificationSetupCompleteView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}

#Preview("Wachtwoord gewijzigd") {
    NavigationStack {
        PasswordResetCompleteView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
