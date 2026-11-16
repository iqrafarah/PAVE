import SwiftUI

/// Your profile: a selection from your vault to share. Sharing does not exist yet, so it honestly shows that it is empty.
struct ProfileScreen: View {
    let onShowMenu: (() -> Void)?

    var body: some View {
        MainEmptyScreen(
            title: "Profiel",
            icon: .iconPerson,
            emptyTitle: "Je hebt nog geen profiel",
            message: "Hier stel je straks een profiel samen om te delen, bijvoorbeeld voor een sollicitatie. Jij kiest wat erin staat en met wie je het deelt.",
            onShowMenu: onShowMenu
        )
    }
}

#Preview {
    ProfileScreen(onShowMenu: {})
}
