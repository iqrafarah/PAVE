import SwiftUI

/// Notifications. There are none yet, so it shows that honestly instead of a made-up count.
struct NotificationsScreen: View {
    let onShowMenu: (() -> Void)?

    var body: some View {
        MainEmptyScreen(
            title: "Meldingen",
            icon: .iconMailOpen,
            emptyTitle: "Je hebt geen meldingen",
            message: "Nieuwe berichten over je plannen en over het bevestigen van je gegevens zie je hier.",
            onShowMenu: onShowMenu
        )
    }
}

#Preview {
    NotificationsScreen(onShowMenu: {})
}
