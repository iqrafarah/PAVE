import PAVECore
import SwiftUI

/// How many pages a document takes in its design, without showing it: for a proposal that has to fit on one page.
enum ApplicationPageMeasure {
    static func pages(_ draft: ApplicationDraft, document: ApplicationDocumentKind = .cv, photo: UIImage?) -> Int {
        let count = ApplicationPageCount()
        let renderer = ImageRenderer(content: ApplicationPages(draft: draft, document: document, photo: photo, count: count))
        // Laying it out is enough; one point of canvas keeps the drawing itself next to nothing.
        guard let context = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 1 }
        renderer.render { _, draw in draw(context) }
        return count.pages
    }
}
