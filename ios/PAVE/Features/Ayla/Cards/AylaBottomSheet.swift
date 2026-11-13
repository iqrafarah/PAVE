import SwiftUI

/// The white panel that slides up over the chat on iPhone (Figma: vacancies and choosing vault items).
/// It follows the finger on its top edge and lands where the swipe would end: the full screen, its own height, or
/// closed, so one swipe down from the full screen closes it. The text field stays on top of it.
struct AylaBottomSheet<Content: View>: View {
    let title: String
    let height: CGFloat
    let expandedHeight: CGFloat
    let bottomInset: CGFloat
    /// Off for content that scrolls itself, such as the vault.
    var scrolls = true
    var background: Color = .white
    let onClose: () -> Void
    @ViewBuilder let content: Content

    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0

    private var currentHeight: CGFloat {
        let base = isExpanded ? expandedHeight : height
        return min(expandedHeight, max(120, base - dragOffset))
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            if scrolls {
                ScrollView {
                    content
                        .padding(.leading, 26)
                        .padding(.trailing, 25)
                        .padding(.bottom, bottomInset)
                }
                .scrollIndicators(.hidden)
            } else {
                content
                    .padding(.bottom, bottomInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: currentHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25, style: .continuous)
                .fill(background)
                .shadow(color: .black.opacity(0.25), radius: 0.7)
                .ignoresSafeArea(edges: [.bottom, .horizontal])
        }
        .overlay(alignment: .bottom) {
            LinearGradient(stops: [.init(color: .white.opacity(0), location: 0), .init(color: .white, location: 0.45)], startPoint: .top, endPoint: .bottom)
                .frame(height: bottomInset)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .bottom)
        }
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
