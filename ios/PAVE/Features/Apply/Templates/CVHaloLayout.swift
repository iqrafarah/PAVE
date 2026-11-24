import PAVECore
import SwiftUI

/// Kring: the photo in the middle of rings of colour, the name in spaced capitals under it, and everything centred
/// under that, with titles between two thin lines.
struct CVHaloLayout: View {
    let draft: ApplicationDraft
    let photo: UIImage?
    let interaction: ApplicationPageInteraction?

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                CVHaloRings(photo: photo, theme: theme, size: photo == nil ? 120 : 190)
                Text((cv.name.isEmpty ? (interaction == nil ? " " : ApplyMessages.name) : cv.name).uppercased())
                    .font(theme.display(26, .light))
                    .tracking(5)
                    .foregroundStyle(theme.dark)
                    .multilineTextAlignment(.center)
                if !cv.headline.isEmpty {
                    Text(cv.headline)
                        .font(theme.body(10.5, .semibold))
                        .foregroundStyle(theme.accent)
                }
                CVContactList(cv: cv, theme: theme, isRow: true)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .applicationBlock(.personal, interaction, accent: theme.accent)
            VStack(alignment: .leading, spacing: 20) {
                CVProfileBlock(cv: cv, theme: theme, titleStyle: .centered, interaction: interaction)
                CVSectionsBlock(cv: cv, theme: theme, titleStyle: { _ in .centered }, entryStyle: .dateRight, interaction: interaction, spacing: 20)
                if !cv.skills.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        CVSectionTitle(title: ApplyMessages.skillsHeading, style: .centered, theme: theme)
                        CVSkillsView(skills: cv.skills, style: .outline, theme: theme)
                    }
                    .applicationBlock(.skills, interaction, accent: theme.accent)
                }
            }
        }
        .padding(.horizontal, 56)
        .padding(.top, 30)
        .padding(.bottom, 44)
        .background(alignment: .top) {
            theme.tint.frame(height: photo == nil ? 90 : 125)
        }
    }
}

/// Rings of the design's colour around the photo; without a photo, around a person icon, never initials.
struct CVHaloRings: View {
    let photo: UIImage?
    let theme: ApplicationTheme
    var size: CGFloat = 190

    var body: some View {
        ZStack {
            Circle().strokeBorder(theme.accent.opacity(0.12), lineWidth: 1)
            Circle().strokeBorder(theme.accent.opacity(0.22), lineWidth: 1).padding(size * 0.1)
            Circle().fill(.white).padding(size * 0.2)
            Circle().strokeBorder(theme.accent.opacity(0.55), lineWidth: 1.5).padding(size * 0.2)
            if let photo {
                CVPhotoView(photo: photo, size: size * 0.56)
            } else {
                Image(.iconUserOutline)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.22, height: size * 0.22)
                    .foregroundStyle(theme.accent)
            }
        }
        .frame(width: size, height: size)
    }
}
