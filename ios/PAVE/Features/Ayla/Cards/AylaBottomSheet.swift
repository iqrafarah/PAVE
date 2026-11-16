import SwiftUI

/// The white panel that slides up over the chat on iPhone (Figma: vacancies and choosing vault items).
/// Drag the grabber down to close it, or up to make it taller. The text field stays on top of it.
struct AylaBottomSheet<Content: View>: View {
    let title: String
    let height: CGFloat
    let expandedHeight: CGFloat
    let bottomInset: CGFloat
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
            ScrollView {
                content
                    .padding(.leading, 26)
                    .padding(.trailing, 25)
                    .padding(.bottom, bottomInset)
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: currentHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25, style: .continuous)
                .fill(Color.white)
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
                        let distance = value.predictedEndTranslation.height
                        withAnimation(.spring(duration: 0.35)) {
                            dragOffset = 0
                            if distance > 160 {
                                if isExpanded { isExpanded = false } else { onClose() }
                            } else if distance < -80 {
                                isExpanded = true
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
