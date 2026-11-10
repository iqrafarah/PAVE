import SwiftUI

extension EnvironmentValues {
    /// Where the menu button is on screen. On the outer display of iPhone Duo it sits in the bar along the side; the
    /// open menu then puts its close button in exactly the same place, as in ChatGPT.
    @Entry var reportMenuButtonFrame: (CGRect) -> Void = { _ in }
    /// The open menu has taken the chat button's place (outer display of iPhone Duo).
    @Entry var hidesChatsButton = false
}
