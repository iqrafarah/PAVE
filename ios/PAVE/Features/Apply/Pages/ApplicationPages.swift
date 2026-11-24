import PAVECore
import SwiftUI

/// The CV or the letter on real A4 pages, in the chosen design. The document is laid out once as one long sheet;
/// `PageFlow` cuts it between its blocks, per column, and every page shows its part. The same view is the editor, the
/// gallery card and the pdf, so what you see is what you send.
struct ApplicationPages: View {
    enum Shows: Equatable {
        /// Every page under the other, with room between them.
        case all(gap: CGFloat)
        /// One page only.
        case page(Int)
    }

    let draft: ApplicationDraft
    let document: ApplicationDocumentKind
    var photo: UIImage?
    var interaction: ApplicationPageInteraction?
    var shows = Shows.page(0)
    var cornerRadius: CGFloat = 0
    var count: ApplicationPageCount?

    @State private var allHeight = ApplicationPage.size.height

    private var size: CGSize { ApplicationPage.size }

    var body: some View {
        // Laid out but not drawn: it says where every block is.
        sheet
            .hidden()
            .frame(width: size.width, height: shows.isOnePage ? size.height : allHeight, alignment: .topLeading)
            .overlayPreferenceValue(ApplicationPageMarks.self, alignment: .topLeading) { marks in
                GeometryReader { proxy in
                    let flow = ApplicationPageFlow(marks: marks, proxy: proxy, margins: ApplicationPage.margins(draft.template, document))
                    let _ = count?.pages = flow.layout.pages
                    pages(flow)
                }
            }
            .environment(\.colorScheme, .light)
            .environment(\.applicationIsEditing, interaction != nil)
    }

    /// The whole document as one long sheet, as tall as its content.
    private var sheet: some View {
        Group {
            switch document {
            case .cv: CVPage(draft: draft, photo: photo, interaction: interaction)
            case .letter: LetterPage(draft: draft, interaction: interaction)
            }
        }
        .frame(width: size.width, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func pages(_ flow: ApplicationPageFlow) -> some View {
        switch shows {
        case .page(let index):
            page(min(index, flow.layout.pages - 1), flow)
        case .all(let gap):
            let total = CGFloat(flow.layout.pages) * size.height + CGFloat(flow.layout.pages - 1) * gap
            ZStack(alignment: .topLeading) {
                ForEach(0..<flow.layout.pages, id: \.self) { index in
                    page(index, flow)
                        .offset(y: CGFloat(index) * (size.height + gap))
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(ApplyMessages.page(index + 1, of: flow.layout.pages))
                }
            }
            .frame(width: size.width, height: total, alignment: .topLeading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { allHeight = $0 }
        }
    }

    private func page(_ index: Int, _ flow: ApplicationPageFlow) -> some View {
        ZStack(alignment: .topLeading) {
            ApplicationPaper(draft: draft, document: document, page: index)
            let pieces = flow.layout.pieces.filter { $0.page == index }
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                let style = flow.panels[piece.panel]
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.fill)
                    .frame(width: piece.frame.width, height: piece.frame.height)
                    .offset(x: piece.frame.minX, y: piece.frame.minY)
            }
            let slices = flow.layout.slices.filter { $0.page == index }
            if index == 0 {
                // Read out and acted on by VoiceOver here, once, for the whole document.
                sheet
                    .mask(alignment: .topLeading) {
                        ApplicationFirstPageMask(
                            size: size,
                            moved: slices.filter { $0.to < size.height }.map { CGRect(x: $0.x, y: $0.to, width: $0.width, height: size.height - $0.to) }
                        )
                        .fill(style: FillStyle(eoFill: true))
                        .frame(width: size.width, height: size.height)
                    }
                    .allowsHitTesting(false)
            } else {
                ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                    sheet
                        .offset(y: slice.shift)
                        .mask(alignment: .topLeading) {
                            Rectangle()
                                .frame(width: slice.width, height: slice.to - slice.from)
                                .offset(x: slice.x, y: slice.top)
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            if let interaction {
                let taps = flow.taps.compactMap { tap in flow.layout.place(of: tap.frame).map { (tap.block, $0.page, $0.frame) } }.filter { $0.1 == index }
                ForEach(Array(taps.enumerated()), id: \.offset) { _, tap in
                    Color.clear
                        .frame(width: tap.2.width, height: tap.2.height)
                        .contentShape(.rect)
                        .onTapGesture { interaction.onSelect(tap.0) }
                        .offset(x: tap.2.minX, y: tap.2.minY)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

private extension ApplicationPages.Shows {
    var isOnePage: Bool {
        if case .page = self { return true }
        return false
    }
}

/// The marks of the long sheet, measured, and the pages they make.
private struct ApplicationPageFlow {
    var layout: PageFlow.Layout
    var panels: [(fill: Color, cornerRadius: CGFloat)] = []
    var taps: [(block: ApplicationBlock, frame: CGRect)] = []

    init(marks: [ApplicationPageMark], proxy: GeometryProxy, margins: (top: CGFloat, bottom: CGFloat)) {
        var regions: [CGRect] = []
        var blocks: [PageFlow.Block] = []
        var flowPanels: [PageFlow.Panel] = []
        for mark in marks {
            let frame = proxy[mark.bounds]
            switch mark.kind {
            case .region: regions.append(frame)
            case .block(let keepsWithNext): blocks.append(PageFlow.Block(frame: frame, keepsWithNext: keepsWithNext))
            case .panel(let fill, let cornerRadius, let padding):
                flowPanels.append(PageFlow.Panel(frame: frame, padding: padding))
                panels.append((fill, cornerRadius))
            case .tap(let block): taps.append((block, frame))
            }
        }
        layout = PageFlow.layout(
            regions: regions, blocks: blocks, panels: flowPanels, page: ApplicationPage.size, topMargin: margins.top, bottomMargin: margins.bottom
        )
    }
}
