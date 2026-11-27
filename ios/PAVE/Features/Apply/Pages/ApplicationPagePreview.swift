import PAVECore
import SwiftUI

/// The first page of a document, to show small: in the gallery, the design panel and while choosing what goes in.
/// It is drawn again only when the document itself changed, not every time something around it does.
nonisolated struct ApplicationPagePreview: View, Equatable {
    let draft: ApplicationDraft
    let document: ApplicationDocumentKind
    nonisolated(unsafe) var photo: UIImage?

    static func == (a: Self, b: Self) -> Bool {
        a.draft == b.draft && a.document == b.document && a.photo === b.photo
    }

    @MainActor var body: some View {
        ApplicationPages(draft: draft, document: document, photo: photo)
    }
}
