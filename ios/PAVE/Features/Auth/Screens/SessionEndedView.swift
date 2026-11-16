import PAVECore
import SwiftUI

/// Shown when the session ended elsewhere, for example because the password was changed on another device.
struct SessionEndedView: View {
    let onSignInAgain: () -> Void

    var body: some View {
        NavigationStack {
            AuthScreen {
                AuthIntro(
                    emblem: .iconSignOut,
                    eyebrow: "Uitgelogd",
                    title: "Log opnieuw in",
                    message: "Je bent op dit apparaat uitgelogd. Dat gebeurt bijvoorbeeld als je wachtwoord is gewijzigd."
                )
            } content: {
                VStack(alignment: .leading, spacing: 24) {
                    PaveNotice(
                        title: "Was jij dit niet?",
                        message: "Kies bij het inloggen 'Wachtwoord vergeten?' en stel een nieuw wachtwoord in. Zo kan alleen jij nog bij je account."
                    )
                    PavePrimaryButton(title: "Opnieuw inloggen", action: onSignInAgain)
                }
            }
        }
    }
}

#Preview {
    SessionEndedView {}
}
