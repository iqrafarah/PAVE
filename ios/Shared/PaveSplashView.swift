import SwiftUI

struct PaveSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false
    /// The colour of the letters and the glow: PAVE green, or the theme colour on the iPhone.
    var accent = Color.brandGreen

    private let letters: [ImageResource] = [.paveLetterP, .paveLetterA, .paveLetterV, .paveLetterE]

    #if os(watchOS)
    private let enterDistance: CGFloat = 28
    #else
    private let enterDistance: CGFloat = 56
    #endif

    var body: some View {
        ZStack {
            Color.canvas

            LinearGradient(
                stops: [
                    .init(color: accent, location: 0),
                    .init(color: .canvas, location: 0.25),
                    .init(color: .canvas, location: 0.74038),
                    .init(color: accent, location: 1),
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .opacity(isRevealed ? 1 : 0)
            .animation(.easeOut(duration: 0.35), value: isRevealed)

            wordmark
        }
        .ignoresSafeArea()
        .task {
            isRevealed = true
        }
    }

    private var wordmark: some View {
        ZStack {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                Image(letter)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(accent)
                    .offset(y: isRevealed || reduceMotion ? 0 : enterDistance)
                    .opacity(isRevealed ? 1 : 0)
                    .animation(animation(forLetterAt: index), value: isRevealed)
            }
        }
        .containerRelativeFrame(.horizontal) { width, _ in width * 0.745 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PAVE")
    }

    private func animation(forLetterAt index: Int) -> Animation {
        if reduceMotion {
            return .easeOut(duration: 0.3)
        }
        return .timingCurve(0.16, 1, 0.3, 1, duration: 0.5)
            .delay(Double(index) * 0.12)
    }
}

#Preview {
    PaveSplashView()
}
