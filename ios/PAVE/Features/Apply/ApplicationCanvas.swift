import PAVECore
import SwiftUI

/// The pages on their canvas, as in Figma: scaled to the room there is, each floating with a soft shadow, and
/// tappable per block. A document longer than A4 goes on on a next page.
struct ApplicationCanvas: View {
    let model: ApplicationStudioModel
    let photo: UIImage?

    @State private var pagesHeight = ApplicationPage.size.height
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let scale = min(1.2, max(0.3, (proxy.size.width - 32) / ApplicationPage.size.width))
            let gap = 20 / scale
            let pages = max(1, Int(((pagesHeight + gap) / (ApplicationPage.size.height + gap)).rounded()))
            ScrollView {
                VStack(spacing: 16) {
                    ApplicationPages(
                        draft: model.shown, document: model.document, photo: photo, interaction: interaction,
                        shows: .all(gap: gap), cornerRadius: 4 / scale, shadowRadius: 14 / scale
                    )
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pagesHeight = $0 }
                    .onChange(of: pages, initial: true) { _, pages in
                        if model.document == .cv { model.pages = pages }
                    }
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: ApplicationPage.size.width * scale, height: pagesHeight * scale, alignment: .topLeading)
                    // One page reads best; said under the pages, where it is in nobody's way.
                    if pages > 1 {
                        VStack(spacing: 2) {
                            Text(ApplyMessages.pagesNote(pages, model.document))
                                .textStyle(.caption)
                                .foregroundStyle(Color.inkMuted)
                                .multilineTextAlignment(.center)
                            if model.document == .cv {
                                Button(ApplyMessages.makeItFit) { model.fitOnOnePage() }
                                    .textStyle(.link)
                                    .foregroundStyle(Color.paveAccent)
                                    .frame(minHeight: 44)
                                    .buttonStyle(.pave)
                            }
                        }
                        .frame(maxWidth: 420)
                        .padding(.horizontal, 24)
                    }
                }
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

    private var interaction: ApplicationPageInteraction {
        ApplicationPageInteraction(
            selection: model.selection,
            writing: model.writing,
            isWritingLetter: model.isWritingLetter,
            writingEntries: model.writingEntries,
            onSelect: { block in
                PaveHaptics.selection()
                model.selection = block
            }
        )
    }
}
