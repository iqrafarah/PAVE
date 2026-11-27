import PAVECore
import SwiftUI

/// Koraal: creative. Large circles of colour behind the photo, a big rounded name over two lines, titles on pills and
/// a timeline.
struct CVCoralLayout: View {
    let draft: ApplicationDraft
    let photo: UIImage?
    let interaction: ApplicationPageInteraction?

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }

    /// "Daaf" and "de Vries": the first name big on its own line.
    private var nameLines: (String, String) {
        let parts = cv.name.split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? "", parts.count > 1 ? parts[1] : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    if cv.name.isEmpty {
                        Text(interaction == nil ? " " : ApplyMessages.name)
                            .font(theme.display(36, .heavy))
                            .foregroundStyle(theme.muted)
                    } else {
                        Text(nameLines.0)
                            .font(theme.display(40, .heavy))
                            .foregroundStyle(theme.dark)
                        if !nameLines.1.isEmpty {
                            Text(nameLines.1)
                                .font(theme.display(26, .bold))
                                .foregroundStyle(theme.accent)
                        }
                    }
                    if !cv.headline.isEmpty {
                        Text(cv.headline)
                            .font(theme.display(11.5, .semibold))
                            .foregroundStyle(theme.ink)
                            .padding(.top, 4)
                    }
                    CVContactList(cv: cv, theme: theme, isRow: true)
                        .padding(.top, 8)
                }
                Spacer(minLength: 0)
                CVPhotoView(photo: photo, size: 128, ring: .white, ringWidth: 6)
                    .padding(.trailing, 8)
            }
            .applicationBlock(.personal, interaction, accent: theme.accent)
            CVProfileBlock(cv: cv, theme: theme, titleStyle: .pill, interaction: interaction)
            CVSectionsBlock(cv: cv, theme: theme, titleStyle: { _ in .pill }, entryStyle: .timeline, interaction: interaction, spacing: 20)
            if !cv.skills.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    CVSectionTitle(title: ApplyMessages.skillsHeading, style: .pill, theme: theme)
                    CVSkillsView(skills: cv.skills, style: .pills, theme: theme)
                }
                .applicationBlock(.skills, interaction, accent: theme.accent)
            }
        }
        .padding(.horizontal, 44)
        .padding(.top, 52)
        .padding(.bottom, 44)
        .background(alignment: .topTrailing) {
            ZStack {
                Circle().fill(theme.tint).frame(width: 330, height: 330).offset(x: 120, y: -150)
                Circle().fill(theme.accent.opacity(0.85)).frame(width: 130, height: 130).offset(x: 20, y: -25)
            }
            .allowsHitTesting(false)
        }
        .clipped()
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageRegion()
    }
}
