import PAVECore
import SwiftUI

/// Kader: minimal. Lots of white, the name in serif in the middle, thin lines, quiet titles and the dates on the left.
struct CVFrameLayout: View {
    let draft: ApplicationDraft
    let photo: UIImage?
    let interaction: ApplicationPageInteraction?

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 8) {
                CVPhotoView(photo: photo, size: 70)
                Text(cv.name.isEmpty ? (interaction == nil ? " " : ApplyMessages.name) : cv.name)
                    .font(theme.display(34, .regular))
                    .tracking(0.6)
                    .foregroundStyle(theme.ink)
                if !cv.headline.isEmpty {
                    Text(cv.headline.uppercased())
                        .font(theme.body(8.5, .medium))
                        .tracking(3)
                        .foregroundStyle(theme.muted)
                }
                CVContactList(cv: cv, theme: theme, isRow: true, iconColor: theme.muted)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .applicationBlock(.personal, interaction, accent: theme.accent)
            Rectangle().fill(theme.ink.opacity(0.85)).frame(height: 0.6)
            CVProfileBlock(cv: cv, theme: theme, titleStyle: .quiet, interaction: interaction)
            CVSectionsBlock(cv: cv, theme: theme, titleStyle: { _ in .quiet }, entryStyle: .dateLeft, interaction: interaction, spacing: 24)
            if !cv.skills.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    CVSectionTitle(title: ApplyMessages.skillsHeading, style: .quiet, theme: theme)
                    CVSkillsView(skills: cv.skills, style: .list, theme: theme)
                }
                .applicationBlock(.skills, interaction, accent: theme.accent)
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageRegion()
    }
}
