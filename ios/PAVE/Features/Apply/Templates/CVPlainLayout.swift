import PAVECore
import SwiftUI

/// Helder: the plain one. One column, the name on the left, titles in capitals with a line, no photo and no colour
/// blocks, so every application system reads it the way it is meant.
struct CVPlainLayout: View {
    let draft: ApplicationDraft
    let photo: UIImage?
    let interaction: ApplicationPageInteraction?

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(cv.name.isEmpty ? (interaction == nil ? " " : ApplyMessages.name) : cv.name)
                        .font(theme.display(26, .bold))
                        .foregroundStyle(cv.name.isEmpty ? theme.muted : theme.ink)
                    if !cv.headline.isEmpty {
                        Text(cv.headline)
                            .font(theme.body(11, .medium))
                            .foregroundStyle(theme.accent)
                    }
                    CVContactList(cv: cv, theme: theme, isRow: true, iconColor: theme.muted)
                        .padding(.top, 6)
                }
                Spacer(minLength: 0)
                CVPhotoView(photo: photo, size: 64, cornerRadius: 8)
            }
            .applicationBlock(.personal, interaction, accent: theme.accent)
            Rectangle().fill(theme.ink).frame(height: 1.2)
            CVProfileBlock(cv: cv, theme: theme, titleStyle: .caps, interaction: interaction)
            CVSectionsBlock(cv: cv, theme: theme, titleStyle: { _ in .caps }, entryStyle: .dateRight, interaction: interaction, spacing: 20)
            if !cv.skills.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    CVSectionTitle(title: ApplyMessages.skillsHeading, style: .caps, theme: theme)
                    CVSkillsView(skills: cv.skills, style: .list, theme: theme)
                }
                .applicationBlock(.skills, interaction, accent: theme.accent)
            }
        }
        .padding(.horizontal, 52)
        .padding(.top, 52)
        .padding(.bottom, 44)
    }
}
