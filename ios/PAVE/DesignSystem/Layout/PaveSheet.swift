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
    /// Chosen once, from the screen the sheet opens on. Not from the size class inside the sheet: a card in the middle
    /// is narrow, so it read "phone" and turned back into a full sheet, which was wide again, and so on. Every turn
    /// built the content anew: on the open iPhone Duo the sheet jumped and a text field lost the keyboard at once.
    @State private var isWide = PaveSheet.screenIsWide

    private static let cornerRadius: CGFloat = 25

    /// The open iPhone Duo and iPad: room for a card in the middle.
    private static var screenIsWide: Bool {
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        return (window?.bounds.width ?? 0) >= 700
    }

    func body(content: Content) -> some View {
        if isWide {
            content
                .paveAnimationsSwitch()
                .presentationSizing(.form)
        } else {
            content
                .paveAnimationsSwitch()
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
