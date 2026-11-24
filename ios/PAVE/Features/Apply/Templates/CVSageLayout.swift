import PAVECore
import SwiftUI

/// Salie: elegant. A soft side column with the photo, contact and skills; the name and titles in serif.
struct CVSageLayout: View {
    let draft: ApplicationDraft
    let photo: UIImage?
    let interaction: ApplicationPageInteraction?

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }
    static let sideWidth: CGFloat = 206

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                CVPhotoView(photo: photo, size: 118, ring: .white, ringWidth: 5)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    CVSectionTitle(title: ApplyMessages.contactHeading, style: .quiet, theme: theme)
                    CVContactList(cv: cv, theme: theme)
                }
                .applicationBlock(.personal, interaction, accent: theme.accent)
                if !cv.skills.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        CVSectionTitle(title: ApplyMessages.skillsHeading, style: .quiet, theme: theme)
                        CVSkillsView(skills: cv.skills, style: .soft, theme: theme)
                    }
                    .applicationBlock(.skills, interaction, accent: theme.accent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 50)
            .frame(width: Self.sideWidth, alignment: .leading)
            .pageRegion()
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(cv.name.isEmpty ? (interaction == nil ? " " : ApplyMessages.name) : cv.name)
                        .font(theme.display(31, .regular))
                        .foregroundStyle(theme.ink)
                    if !cv.headline.isEmpty {
                        Text(cv.headline.uppercased())
                            .font(theme.body(9.5, .semibold))
                            .tracking(2.2)
                            .foregroundStyle(theme.accent)
                    }
                }
                .applicationBlock(.personal, interaction, accent: theme.accent)
                CVProfileBlock(cv: cv, theme: theme, titleStyle: .serif, interaction: interaction)
                CVSectionsBlock(cv: cv, theme: theme, titleStyle: { _ in .serif }, entryStyle: .dateRight, interaction: interaction, spacing: 24)
            }
            .padding(.horizontal, 34)
            .padding(.top, 54)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageRegion()
        }
    }
}
