import SwiftUI

extension View {
    /// How PAVE presents a sheet. On a phone it slides up but stops beside the status column of the iPhone Duo's outer
    /// display instead of running under it. On wider screens (iPad, the open iPhone Duo) it is a card in the middle.
    func paveSheet() -> some View {
        modifier(PaveSheet())
    }
}

private struct PaveSheet: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    private static let cornerRadius: CGFloat = 25

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
                .presentationSizing(.form)
        } else {
            content
                // The content keeps out of the status column by itself; only its backgrounds run under it. Cutting
                // everything off at the content's own edges makes the sheet stop beside the column. Downwards the mask
                // goes on, so the background still reaches the bottom of the screen.
                .mask {
                    UnevenRoundedRectangle(
                        topLeadingRadius: Self.cornerRadius,
                        topTrailingRadius: Self.cornerRadius,
                        style: .continuous
                    )
                    .padding(.bottom, -200)
                }
            .presentationBackground(.clear)
            .presentationCornerRadius(Self.cornerRadius)
        }
    }
}
