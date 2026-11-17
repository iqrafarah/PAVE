import SwiftUI

/// The white panel that slides up over the chat on iPhone (Figma: vacancies). It follows the finger on its top edge
/// and lands where the swipe would end: the full screen, its own height, or closed, so one swipe down from the full
/// screen closes it. The text field stays on top of it.
///
/// The panel always has its full height and only moves: sliding is a shift the screen draws as it is, while changing
/// the height would lay out everything in it again on every frame.
struct AylaBottomSheet<Content: View>: View {
    let title: String
    let height: CGFloat
    let expandedHeight: CGFloat
    let bottomInset: CGFloat
    let onClose: () -> Void
    @ViewBuilder let content: Content

    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0

    private var visibleHeight: CGFloat {
        let base = isExpanded ? expandedHeight : height
        return min(expandedHeight, max(120, base - dragOffset))
    }

    /// The part below the screen at rest, so the end of the content can still be scrolled into view.
    private var hiddenAtRest: CGFloat {
        isExpanded ? 0 : expandedHeight - height
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            ScrollView {
                content
                    .padding(.leading, 26)
                    .padding(.trailing, 25)
                    .padding(.bottom, bottomInset + hiddenAtRest)
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: expandedHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 0.7)
                .ignoresSafeArea(edges: [.bottom, .horizontal])
        }
        // The fade under the text field, at the bottom of the screen wherever the panel is.
        .overlay(alignment: .bottom) {
            LinearGradient(stops: [.init(color: .white.opacity(0), location: 0), .init(color: .white, location: 0.45)], startPoint: .top, endPoint: .bottom)
                .frame(height: bottomInset)
                .offset(y: -(expandedHeight - visibleHeight))
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: expandedHeight - visibleHeight)
        .transition(.move(edge: .bottom))
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.grabber)
            .frame(width: 52, height: 4)
            .padding(.top, 16)
            .padding(.bottom, 23)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = $0.translation.height }
                    .onEnded { value in
                        // Where the swipe would end, with its speed: the nearest of full, own height or closed.
                        let end = (isExpanded ? expandedHeight : height) - value.predictedEndTranslation.height
                        withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                            dragOffset = 0
                            if end < height * 0.55 {
                                onClose()
                            } else {
                                isExpanded = abs(end - expandedHeight) < abs(end - height)
                            }
                        }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Sluit het paneel")
            .accessibilityAction { onClose() }
    }
}
