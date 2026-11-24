import PAVECore
import SwiftUI

/// Zuil: modern. A dark band across the top with the name in capitals, the photo half over its edge, and two columns
/// below: contact, skills and education on the left, the rest on the right.
struct CVColumnLayout: View {
    let draft: ApplicationDraft
    let photo: UIImage?
    let interaction: ApplicationPageInteraction?

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }
    private var hasPhoto: Bool { photo != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text((cv.name.isEmpty ? (interaction == nil ? " " : ApplyMessages.name) : cv.name).uppercased())
                    .font(theme.display(28, .black))
                    .tracking(2.4)
                    .foregroundStyle(.white)
                if !cv.headline.isEmpty {
                    Text(cv.headline)
                        .font(theme.body(11, .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Capsule().fill(theme.accent).frame(width: 40, height: 3).padding(.top, 6)
            }
            .padding(.leading, hasPhoto ? 190 : 44)
            .padding(.trailing, 44)
            .padding(.top, 48)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.dark)
            .overlay(alignment: .bottomLeading) {
                CVPhotoView(photo: photo, size: 116, ring: .white, ringWidth: 5)
                    .offset(x: 44, y: 46)
            }
            .applicationBlock(.personal, interaction, accent: theme.accent)
            .zIndex(1)
            HStack(alignment: .top, spacing: 30) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 9) {
                        CVSectionTitle(title: ApplyMessages.contactHeading, style: .caps, theme: theme)
                        CVContactList(cv: cv, theme: theme)
                    }
                    .applicationBlock(.personal, interaction, accent: theme.accent)
                    if !cv.skills.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            CVSectionTitle(title: ApplyMessages.skillsHeading, style: .caps, theme: theme)
                            CVSkillsView(skills: cv.skills, style: .pills, theme: theme)
                        }
                        .applicationBlock(.skills, interaction, accent: theme.accent)
                    }
                    CVSectionsBlock(cv: cv, theme: theme, titleStyle: { _ in .caps }, entryStyle: .stacked, kinds: [.education, .certificates], interaction: interaction)
                }
                .frame(width: 170, alignment: .leading)
                .pageRegion()
                VStack(alignment: .leading, spacing: 22) {
                    CVProfileBlock(cv: cv, theme: theme, titleStyle: .caps, interaction: interaction)
                    CVSectionsBlock(cv: cv, theme: theme, titleStyle: { _ in .caps }, entryStyle: .dateRight, kinds: [.experience, .projects], interaction: interaction)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .pageRegion()
            }
            .padding(.horizontal, 44)
            .padding(.top, hasPhoto ? 70 : 34)
            .padding(.bottom, 44)
        }
    }
}
