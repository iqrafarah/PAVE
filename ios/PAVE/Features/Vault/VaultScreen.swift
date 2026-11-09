import SwiftUI

/// The vault. There is no vault in the database yet, so it honestly shows that it is empty.
struct VaultScreen: View {
    let onShowMenu: (() -> Void)?

    var body: some View {
        MainEmptyScreen(
            title: "Kluis",
            icon: .iconFolder,
            emptyTitle: "Je kluis is nog leeg",
            message: "Hier bewaar je straks je diploma's, certificaten, projecten en ervaringen, zodat je alles op één plek hebt.",
            onShowMenu: onShowMenu
        )
    }
}

#Preview {
    VaultScreen(onShowMenu: {})
}
