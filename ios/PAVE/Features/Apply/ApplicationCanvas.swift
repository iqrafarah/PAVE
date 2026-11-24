import PAVECore
import SwiftUI

/// The page on its canvas, as in Figma: scaled to the room there is, floating with a soft shadow, and tappable per
/// block. A page longer than A4 shows where the next page starts.
struct ApplicationCanvas: View {
    let model: ApplicationStudioModel
    let photo: UIImage?

    @State private var pageHeight = ApplicationPage.size.height
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let scale = min(1.2, max(0.3, (proxy.size.width - 32) / ApplicationPage.size.width))
            ScrollView {
                page
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: ApplicationPage.size.width * scale, height: pageHeight * scale, alignment: .topLeading)
                    .clipShape(.rect(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
                    .overlay(alignment: .topLeading) { pageBreaks(scale: scale) }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .id(model.document)
                    .transition(.opacity)
            }
            .scrollIndicators(.hidden)
            .background(Color.tileFill)
            .contentShape(.rect)
            .onTapGesture { model.selection = nil }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.document)
        }
    }

    @ViewBuilder
    private var page: some View {
        let interaction = ApplicationPageInteraction(
            selection: model.selection,
            writing: model.writing,
            isWritingLetter: model.isWritingLetter,
            onSelect: { block in
                PaveHaptics.selection()
                model.selection = block
            }
        )
        switch model.document {
        case .cv: CVPage(draft: model.draft, photo: photo, interaction: interaction)
        case .letter: LetterPage(draft: model.draft, interaction: interaction)
        }
    }

    /// A dashed line where a printed page ends, when there is more than one.
    @ViewBuilder
    private func pageBreaks(scale: CGFloat) -> some View {
        let pages = Int((pageHeight / ApplicationPage.size.height).rounded(.up))
        if pages > 1 {
            ForEach(1..<pages, id: \.self) { page in
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(Color.inkMuted.opacity(0.5))
                    .frame(width: ApplicationPage.size.width * scale, height: 1)
                    .offset(y: ApplicationPage.size.height * scale * CGFloat(page))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}
