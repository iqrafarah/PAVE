import SwiftUI

extension View {
    /// The header of a screen you open from the menu: the menu button (when the menu is not already on screen)
    /// and the title with PAVE's slash.
    func mainScreenToolbar(_ title: String, onShowMenu: (() -> Void)?) -> some View {
        toolbar {
            if let onShowMenu {
                ToolbarItem(placement: .topBarLeading) {
                    MainMenuToolbarButton(action: onShowMenu)
                }
            }
            ToolbarItem(placement: .principal) {
                PaveTitle(title)
                    .offset(y: 4)
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}
