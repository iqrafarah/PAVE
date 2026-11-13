import SwiftUI

extension EnvironmentValues {
    /// Where the menu button is on screen. On the outer display of iPhone Duo it sits in the bar along the side; the
    /// open menu then puts its close button in exactly the same place, as in ChatGPT.
    @Entry var reportMenuButtonFrame: (CGRect) -> Void = { _ in }
    /// The open menu has taken the place of the buttons on the right of the screen (outer display of iPhone Duo).
    @Entry var hidesScreenButtons = false
    /// The toolbar buttons sit in the bar along the side of the screen (outer display of iPhone Duo), in larger circles.
    @Entry var toolbarIsBeside = false
    /// The vault is in a sheet on the outer display of iPhone Duo, where iOS shows no toolbar buttons: search and add
    /// sit in the page itself.
    @Entry var vaultButtonsInPage = false
}

extension EnvironmentValues {
    /// When "Zoeken in chats" was asked for with the keyboard; the search field of the chats takes the keyboard.
    @Entry var chatSearchRequestedAt: Date?
}
