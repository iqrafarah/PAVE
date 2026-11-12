import SwiftUI

/// Icons grow and shrink with the text size, like the text next to them (Instellingen › Weergave › Tekstgrootte). They
/// grow at most 40%, so rows and buttons keep their shape at the largest sizes.
private struct PaveIconSize: ViewModifier {
    enum Kind {
        case square(CGFloat)
        case height(CGFloat)
        case scale
    }

    let kind: Kind
    @ScaledMetric(relativeTo: .body) private var scaled: CGFloat = 1

    private var factor: CGFloat { min(scaled, 1.4) }

    func body(content: Content) -> some View {
        switch kind {
        case .square(let size):
            content.frame(width: size * factor, height: size * factor)
        case .height(let height):
            content.frame(height: height * factor)
        case .scale:
            content.scaleEffect(factor)
        }
    }
}

extension View {
    /// A square icon of `size` points at the standard text size.
    func paveIconFrame(_ size: CGFloat) -> some View {
        modifier(PaveIconSize(kind: .square(size)))
    }

    /// A resizable icon of `height` points at the standard text size, as wide as its shape makes it.
    func paveIconHeight(_ height: CGFloat) -> some View {
        modifier(PaveIconSize(kind: .height(height)))
    }

    /// An icon drawn at a fixed size, like Ayla's pixel A, scaled with the text; put it in a `paveIconFrame`.
    func paveIconScale() -> some View {
        modifier(PaveIconSize(kind: .scale))
    }
}
