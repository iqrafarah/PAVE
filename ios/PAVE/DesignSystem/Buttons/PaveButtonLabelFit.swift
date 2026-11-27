import SwiftUI

extension View {
    /// A button label on one line, shrinking a little for a long word in another language; at the accessibility text
    /// sizes it may take up to three lines instead, so no word is cut off.
    func paveButtonLabelFit() -> some View {
        modifier(PaveButtonLabelFit())
    }
}

private struct PaveButtonLabelFit: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.center)
    }
}
