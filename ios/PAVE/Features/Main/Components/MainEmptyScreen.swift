import SwiftUI

/// A screen from the menu that has nothing in it yet: its title at the top and an honest empty state in the middle.
struct MainEmptyScreen: View {
    let title: String
    let icon: ImageResource
    let emptyTitle: String
    let message: String
    let onShowMenu: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                PaveEmptyState(icon: icon, title: emptyTitle, message: message)
                    .padding(.horizontal, 32)
                    .containerRelativeFrame(.vertical)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.canvas.ignoresSafeArea())
            .mainScreenToolbar(title, onShowMenu: onShowMenu)
        }
    }
}

#Preview {
    MainEmptyScreen(title: "Profiel", icon: .iconPerson, emptyTitle: "Je hebt nog geen profiel", message: "Uitleg", onShowMenu: {})
}
