import PAVECore
import SwiftUI

/// The CV on one A4 page in the chosen design. The same view is the preview, the gallery card and the pdf, so what you
/// see is what you send.
struct CVPage: View {
    let draft: ApplicationDraft
    var photo: UIImage?
    var interaction: ApplicationPageInteraction?

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var shownPhoto: UIImage? { draft.showsPhoto ? photo : nil }

    var body: some View {
        Group {
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
        .frame(width: ApplicationPage.size.width, alignment: .topLeading)
        .frame(minHeight: ApplicationPage.size.height, alignment: .top)
        // Side columns run down the whole page, also below their content.
        .background(alignment: .leading) {
            switch draft.template {
            case .sage: theme.tint.frame(width: CVSageLayout.sideWidth)
            case .night: theme.dark.frame(width: CVNightLayout.sideWidth)
            case .block: theme.tint
            default: EmptyView()
            }
        }
        .background(ApplicationPage.paper)
        .clipped()
        .environment(\.colorScheme, .light)
    }
}
