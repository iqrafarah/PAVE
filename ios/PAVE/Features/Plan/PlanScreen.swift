import SwiftUI

/// Plans. There are no plans in the database yet, so it honestly shows that there are none.
struct PlanScreen: View {
    let onShowMenu: (() -> Void)?

    var body: some View {
        MainEmptyScreen(
            title: "Plan",
            icon: .iconMap,
            emptyTitle: "Je hebt nog geen plan",
            message: "Hier komen straks je doelen, wat je al kunt en je volgende stappen te staan.",
            onShowMenu: onShowMenu
        )
    }
}

#Preview {
    PlanScreen(onShowMenu: {})
}
