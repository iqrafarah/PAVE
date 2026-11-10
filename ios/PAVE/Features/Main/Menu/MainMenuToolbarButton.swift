import SwiftUI

/// The menu button at the top left. A standard toolbar button, so iOS draws it as glass
/// and moves it into the bar along the side on the outer display of iPhone Duo.
struct MainMenuToolbarButton: View {
    let action: () -> Void

    @Environment(\.reportMenuButtonFrame) private var reportFrame

    var body: some View {
        Button {
            PaveHaptics.tap(.light)
            action()
        } label: {
            Image(.iconMenu)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reportFrame($0) }
        }
        .accessibilityLabel("Menu")
    }
}
