import SwiftUI

extension View {
    /// How PAVE presents a sheet. On a phone it slides up but stops beside the status column of the iPhone Duo's outer
    /// display instead of running under it. On wider screens (iPad, the open iPhone Duo) it is a card in the middle.
    /// `background` is the colour of the page in it: the sheet itself takes it too, so where the system still shows the
    /// sheet (beside the status column, at a lower height) it is the same surface instead of glass or white.
    /// `clipsToColumn` off lets the content draw into the status column too, for a page that puts buttons there.
    func paveSheet(background: Color? = nil, clipsToColumn: Bool = true) -> some View {
        modifier(PaveSheet(background: background, clipsToColumn: clipsToColumn))
    }
}

private struct PaveSheet: ViewModifier {
    let background: Color?
    let clipsToColumn: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    private static let cornerRadius: CGFloat = 25

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
                .presentationSizing(.form)
        } else {
            content
                // Always an opaque ground: without it a sheet shows the glass of iOS 26 (or the app through it) behind
                // lists, loading and empty states, which makes the text hard to read.
                .background(Color.canvas.ignoresSafeArea(edges: .bottom))
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
                    .padding(.horizontal, clipsToColumn ? 0 : -200)
                }
            .presentationBackground(background ?? .clear)
            .presentationCornerRadius(Self.cornerRadius)
        }
    }
}
