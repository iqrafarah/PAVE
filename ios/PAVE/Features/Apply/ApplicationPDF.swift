import PAVECore
import SwiftUI

/// The CV or the letter as a pdf, drawn from the same view as the preview, in vectors, cut into A4 pages.
enum ApplicationPDF {
    @MainActor
    static func file(for draft: ApplicationDraft, document: ApplicationDocumentKind, photo: UIImage?) throws -> URL {
        let page: AnyView = switch document {
        case .cv: AnyView(CVPage(draft: draft, photo: photo))
        case .letter: AnyView(LetterPage(draft: draft))
        }
        let renderer = ImageRenderer(content: page.frame(width: ApplicationPage.size.width))
        renderer.proposedSize = ProposedViewSize(width: ApplicationPage.size.width, height: nil)
        let name = [document == .cv ? "Cv" : "Motivatiebrief", draft.cv.name, draft.vacancy.company]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "/", with: "-")
        let url = URL.temporaryDirectory.appending(path: "\(name).pdf")
        var failed = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: ApplicationPage.size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
                failed = true
                return
            }
            let pages = max(1, Int((size.height / ApplicationPage.size.height).rounded(.up)))
            for page in 0..<pages {
                context.beginPDFPage(nil)
                context.saveGState()
                // The renderer draws the whole view with its top at `size.height` (pdf counts from the bottom): each
                // page shifts it so the next A4 piece of it lies in the page.
                context.translateBy(x: 0, y: -(size.height - ApplicationPage.size.height * CGFloat(page + 1)))
                draw(context)
                context.restoreGState()
                context.endPDFPage()
            }
            context.closePDF()
        }
        if failed { throw CocoaError(.fileWriteUnknown) }
        return url
    }
}
