import PAVECore
import SwiftUI

/// Nacht: business. A dark side column with the photo in a rounded square, contact and skills; icons before the
/// titles, the dates in their own column.
struct CVNightLayout: View {
    let draft: ApplicationDraft
    let photo: UIImage?
    let interaction: ApplicationPageInteraction?

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }
    static let sideWidth: CGFloat = 200

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                CVPhotoView(photo: photo, size: 128, cornerRadius: 22)
                VStack(alignment: .leading, spacing: 10) {
                    CVSectionTitle(title: ApplyMessages.contactHeading, style: .quiet, theme: theme, onDark: true)
                    CVContactList(cv: cv, theme: theme, onDark: true, iconColor: theme.accent)
                }
                .applicationBlock(.personal, interaction, accent: .white)
                if !cv.skills.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        CVSectionTitle(title: ApplyMessages.skillsHeading, style: .quiet, theme: theme, onDark: true)
                        CVSkillsView(skills: cv.skills, style: .pills, theme: theme, onDark: true)
                    }
                    .applicationBlock(.skills, interaction, accent: .white)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 44)
            .frame(width: Self.sideWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(cv.name.isEmpty ? (interaction == nil ? " " : ApplyMessages.name) : cv.name)
                        .font(theme.display(30, .heavy))
                        .foregroundStyle(theme.dark)
                    if !cv.headline.isEmpty {
                        Text(cv.headline)
                            .font(theme.body(11.5, .semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
                .applicationBlock(.personal, interaction, accent: theme.accent)
                CVProfileBlock(cv: cv, theme: theme, titleStyle: .icon(.iconUserOutline), interaction: interaction)
                CVSectionsBlock(cv: cv, theme: theme, titleStyle: { .icon(CVSectionsBlock.icon($0)) }, entryStyle: .dateLeft, interaction: interaction, spacing: 22)
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
