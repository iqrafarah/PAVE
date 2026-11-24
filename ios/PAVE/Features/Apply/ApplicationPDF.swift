import PAVECore
import SwiftUI

/// The CV or the letter as a pdf, drawn from the same pages as the preview, in vectors, one A4 page each.
enum ApplicationPDF {
    @MainActor
    static func file(for draft: ApplicationDraft, document: ApplicationDocumentKind, photo: UIImage?) throws -> URL {
        let name = [document == .cv ? "Cv" : "Motivatiebrief", draft.cv.name, draft.vacancy.company]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "/", with: "-")
        let url = URL.temporaryDirectory.appending(path: "\(name).pdf")
        var box = CGRect(origin: .zero, size: ApplicationPage.size)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { throw CocoaError(.fileWriteUnknown) }
        // Drawing the first page tells how many there are.
        let count = ApplicationPageCount()
        var page = 0
        repeat {
            let renderer = ImageRenderer(content: ApplicationPages(draft: draft, document: document, photo: photo, shows: .page(page), count: count))
            context.beginPDFPage(nil)
            renderer.render { _, draw in draw(context) }
            context.endPDFPage()
            page += 1
        } while page < count.pages
        context.closePDF()
        return url
    }
}
