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
    /// A soft shadow under every page, drawn from the paper only so it costs nothing while the content changes.
    var shadowRadius: CGFloat = 0
    var count: ApplicationPageCount?
    var onPageCount: ((Int) -> Void)?

    @State private var allHeight = ApplicationPage.size.height

    private var size: CGSize { ApplicationPage.size }
    private var margins: (top: CGFloat, bottom: CGFloat) { ApplicationPage.margins(draft.template, document) }
    /// The long sheet itself is the first page; another single page is drawn from a copy.
    private var showsFirst: Bool {
        if case .page(let index) = shows { return index == 0 }
        return true
    }

    var body: some View {
        // The long sheet, held to the first page: it is that page, and it says where every block is.
        sheet
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .allowsHitTesting(false)
            .opacity(showsFirst ? 1 : 0)
            .backgroundPreferenceValue(ApplicationPageMarks.self, alignment: .topLeading) { marks in
                GeometryReader { proxy in
                    if showsFirst { paper(0, ApplicationPageFlow(marks: marks, proxy: proxy, margins: margins)) }
                }
            }
            .overlayPreferenceValue(ApplicationPageMarks.self, alignment: .topLeading) { marks in
                GeometryReader { proxy in
                    let flow = ApplicationPageFlow(marks: marks, proxy: proxy, margins: margins)
                    let _ = count?.pages = flow.layout.pages
                    pages(flow)
                        .onChange(of: flow.layout.pages, initial: true) { _, pages in onPageCount?(pages) }
                }
            }
            .frame(width: size.width, height: shows.isAll ? allHeight : size.height, alignment: .topLeading)
            .environment(\.colorScheme, .light)
            .environment(\.applicationIsEditing, interaction != nil)
            .environment(\.applicationMarksVerified, draft.marksVerified)
    }

    /// At the foot of the last page of a CV with a tick on it: what the tick means.
    @ViewBuilder
    private func verifiedNote(_ index: Int, _ flow: ApplicationPageFlow) -> some View {
        if document == .cv, index == flow.layout.pages - 1, ApplicationVerification.showsTick(draft) {
            CVVerifiedNote(theme: ApplicationTheme(draft))
                .offset(x: ApplicationPage.noteLeading(draft.template), y: size.height - min(margins.bottom, 40) + 8)
                .allowsHitTesting(false)
        }
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
            let index = min(index, flow.layout.pages - 1)
            if index == 0 { firstPageCover(flow) } else { laterPage(index, flow) }
        case .all(let gap):
            let total = CGFloat(flow.layout.pages) * size.height + CGFloat(flow.layout.pages - 1) * gap
            ZStack(alignment: .topLeading) {
                firstPageCover(flow)
                ForEach(1..<max(1, flow.layout.pages), id: \.self) { index in
                    laterPage(index, flow)
                        .offset(y: CGFloat(index) * (size.height + gap))
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(ApplyMessages.page(index + 1, of: flow.layout.pages))
                }
            }
            .frame(width: size.width, height: total, alignment: .topLeading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { allHeight = $0 }
        }
    }

    /// The paper of a page with the tiles and tinted columns that lie on it, behind the content.
    private func paper(_ index: Int, _ flow: ApplicationPageFlow) -> some View {
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
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .background {
            if shadowRadius > 0 {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.10), radius: shadowRadius, y: shadowRadius * 0.4)
            }
        }
    }

    /// Over the first page: paper again where a full column went on to the next page, and the places to tap.
    private func firstPageCover(_ flow: ApplicationPageFlow) -> some View {
        let moved = flow.layout.slices
            .filter { $0.page == 0 && $0.to < size.height }
            .map { CGRect(x: $0.x, y: $0.to, width: $0.width, height: size.height - $0.to) }
        return ZStack(alignment: .topLeading) {
            if !moved.isEmpty {
                paper(0, flow)
                    .mask(alignment: .topLeading) {
                        ApplicationMovedColumns(rects: moved).frame(width: size.width, height: size.height)
                    }
                    .allowsHitTesting(false)
            }
            verifiedNote(0, flow)
            taps(0, flow)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// A following page: its paper, and per column the part of the long sheet that belongs on it.
    private func laterPage(_ index: Int, _ flow: ApplicationPageFlow) -> some View {
        ZStack(alignment: .topLeading) {
            paper(index, flow)
            let slices = flow.layout.slices.filter { $0.page == index }
            ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                // VoiceOver reads and acts on the whole document through the first page, once.
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
            verifiedNote(index, flow)
            taps(index, flow)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(.rect(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private func taps(_ index: Int, _ flow: ApplicationPageFlow) -> some View {
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
}

private extension ApplicationPages.Shows {
    var isAll: Bool {
        if case .all = self { return true }
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
