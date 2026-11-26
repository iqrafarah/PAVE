import PAVECore
import SwiftUI

/// The paper of one page, behind the content: white, with what a design runs down every page (the side column of
/// Salie and Nacht, the soft ground of Tegel, the line of Lijn's letter).
struct ApplicationPaper: View {
    let draft: ApplicationDraft
    let document: ApplicationDocumentKind
    let page: Int

    private var theme: ApplicationTheme { ApplicationTheme(draft) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ApplicationPage.paper
            switch (document, draft.template) {
            case (.cv, .sage): theme.tint.frame(width: CVSageLayout.sideWidth)
            case (.cv, .night): theme.dark.frame(width: CVNightLayout.sideWidth)
            case (.cv, .block): theme.tint
            case (.letter, .sage): theme.tint.frame(width: 18)
            case (.letter, .line): Rectangle().fill(theme.accent.opacity(0.35)).frame(width: 1.5).padding(.leading, 40)
            case (.letter, .block):
                // A white sheet on the soft page, under the tile with the name on the first page.
                theme.tint
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .padding(.horizontal, 28)
                    .padding(.top, page == 0 ? 28 + LetterPage.blockHeaderHeight + 12 : 28)
                    .padding(.bottom, 28)
            default: EmptyView()
            }
        }
        .frame(width: ApplicationPage.size.width, height: ApplicationPage.size.height, alignment: .topLeading)
    }
}
