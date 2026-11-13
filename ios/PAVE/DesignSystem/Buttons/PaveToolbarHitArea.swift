import SwiftUI

extension View {
    /// A toolbar icon that can be tapped on nearly the whole of its glass circle. iOS hit-tests only the icon itself
    /// (about 21 by 36 points in a 44-point circle), so a tap near the edge did nothing. The toolbar draws the glass as
    /// wide as the icon plus a margin, at least 44: at 32 points the circle stays exactly as it was and nearly all of
    /// it taps. In the bar along the side of iPhone Duo's outer display the circles are larger, so the icon is too.
    func paveToolbarHitArea() -> some View {
        modifier(PaveToolbarHitArea())
    }
}

private struct PaveToolbarHitArea: ViewModifier {
    @Environment(\.toolbarIsBeside) private var isBeside

    func body(content: Content) -> some View {
        content
            .frame(width: isBeside ? 40 : 32, height: isBeside ? 40 : 36)
            .contentShape(.rect)
    }
}
