import PAVECore
import SwiftUI

/// The CV in the chosen design, as one long sheet; `ApplicationPages` cuts it into A4 pages.
struct CVPage: View {
    let draft: ApplicationDraft
    var photo: UIImage?
    var interaction: ApplicationPageInteraction?

    private var shownPhoto: UIImage? { draft.showsPhoto ? photo : nil }

    var body: some View {
        switch draft.template {
        case .sage: CVSageLayout(draft: draft, photo: shownPhoto, interaction: interaction)
        case .night: CVNightLayout(draft: draft, photo: shownPhoto, interaction: interaction)
        case .frame: CVFrameLayout(draft: draft, photo: shownPhoto, interaction: interaction)
        case .coral: CVCoralLayout(draft: draft, photo: shownPhoto, interaction: interaction)
        case .column: CVColumnLayout(draft: draft, photo: shownPhoto, interaction: interaction)
        case .line: CVLineLayout(draft: draft, photo: shownPhoto, interaction: interaction)
        case .plain: CVPlainLayout(draft: draft, photo: shownPhoto, interaction: interaction)
        case .block: CVBlockLayout(draft: draft, photo: shownPhoto, interaction: interaction)
        case .halo: CVHaloLayout(draft: draft, photo: shownPhoto, interaction: interaction)
        case .tilt: CVTiltLayout(draft: draft, photo: shownPhoto, interaction: interaction)
        }
    }
}
