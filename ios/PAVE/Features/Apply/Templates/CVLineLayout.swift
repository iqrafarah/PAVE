import PAVECore
import SwiftUI

/// Lijn: a timeline down the page. A clear header, contact in one row, and every entry as a point on the line with
/// its dates in monospace.
struct CVLineLayout: View {
    let draft: ApplicationDraft
    let photo: UIImage?
    let interaction: ApplicationPageInteraction?

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 18) {
                CVPhotoView(photo: photo, size: 74, ring: theme.tint, ringWidth: 4)
                VStack(alignment: .leading, spacing: 5) {
                    Text(cv.name.isEmpty ? (interaction == nil ? " " : ApplyMessages.name) : cv.name)
                        .font(theme.display(30, .bold))
                        .foregroundStyle(theme.ink)
                    if !cv.headline.isEmpty {
                        Text(cv.headline)
                            .font(theme.mono(10, .medium))
                            .foregroundStyle(theme.accent)
                    }
                    CVContactList(cv: cv, theme: theme, isRow: true)
                        .padding(.top, 4)
                }
            }
            .applicationBlock(.personal, interaction, accent: theme.accent)
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) { Rectangle().fill(theme.accent).frame(height: 3).offset(y: 14) }
            CVProfileBlock(cv: cv, theme: theme, titleStyle: .caps, interaction: interaction)
                .padding(.top, 10)
            CVSectionsBlock(cv: cv, theme: theme, titleStyle: { _ in .caps }, entryStyle: .timeline, interaction: interaction, spacing: 20)
            if !cv.skills.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    CVSectionTitle(title: ApplyMessages.skillsHeading, style: .caps, theme: theme)
                    CVSkillsView(skills: cv.skills, style: .outline, theme: theme)
                }
                .applicationBlock(.skills, interaction, accent: theme.accent)
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 50)
    }
}
