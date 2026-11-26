import SwiftUI

extension Label where Title == Text, Icon == Image {
    /// A menu item whose icon takes the app's colour, like the others in the menu. Some icons have their own grey for
    /// light and dark mode, and a menu would show that grey instead.
    init(_ title: String, tinted image: ImageResource) {
        self.init { Text(title) } icon: { Image(image).renderingMode(.template) }
    }
}
