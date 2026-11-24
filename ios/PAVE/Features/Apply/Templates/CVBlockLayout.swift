import PAVECore
import SwiftUI

/// Tegel: every part on its own white tile on a soft page, as in a bento grid. A tile of colour with the photo and the
/// name on top, the story on the left, the short facts on the right.
struct CVBlockLayout: View {
    let draft: ApplicationDraft
    let photo: UIImage?
    let interaction: ApplicationPageInteraction?

    static let gap: CGFloat = 12
    private static let sideWidth: CGFloat = 180
    private static let mainKinds: Set<CVSection.Kind> = [.experience, .projects]

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }
    private var sections: [CVSection] { cv.visibleSections.filter { $0.entries.contains(where: \.isVisible) } }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            header
            HStack(alignment: .top, spacing: Self.gap) {
                VStack(alignment: .leading, spacing: Self.gap) {
                    if !cv.profile.isEmpty || interaction != nil {
                        tile { CVProfileBlock(cv: cv, theme: theme, titleStyle: .icon(.iconUserOutline), interaction: interaction) }
                    }
                    ForEach(sections.filter { Self.mainKinds.contains($0.kind) }) { section in
                        tile { sectionBlock(section.kind) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: Self.gap) {
                    if !cv.skills.isEmpty {
                        tile {
                            VStack(alignment: .leading, spacing: 10) {
                                CVSectionTitle(title: ApplyMessages.skillsHeading, style: .icon(.iconLightBulbOutline), theme: theme)
                                CVSkillsView(skills: cv.skills, style: .pills, theme: theme)
                            }
                            .applicationBlock(.skills, interaction, accent: theme.accent)
                        }
                    }
                    ForEach(sections.filter { !Self.mainKinds.contains($0.kind) }) { section in
                        tile { sectionBlock(section.kind) }
                    }
                }
                .frame(width: Self.sideWidth, alignment: .leading)
            }
        }
        .padding(28)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            CVPhotoView(photo: photo, size: 92, cornerRadius: 18, ring: .white.opacity(0.9), ringWidth: 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(cv.name.isEmpty ? (interaction == nil ? " " : ApplyMessages.name) : cv.name)
                    .font(theme.display(28, .heavy))
                    .foregroundStyle(.white)
                if !cv.headline.isEmpty {
                    Text(cv.headline)
                        .font(theme.body(11, .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                CVContactList(cv: cv, theme: theme, isRow: true, onDark: true)
                    .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accent, in: .rect(cornerRadius: 18))
        .overlay(alignment: .topTrailing) {
            Circle().fill(.white.opacity(0.10)).frame(width: 120, height: 120).offset(x: 30, y: -40)
                .clipShape(.rect(cornerRadius: 18))
        }
        .clipShape(.rect(cornerRadius: 18))
        .applicationBlock(.personal, interaction, accent: theme.accent)
    }

    private func sectionBlock(_ kind: CVSection.Kind) -> some View {
        CVSectionsBlock(cv: cv, theme: theme, titleStyle: { .icon(CVSectionsBlock.icon($0)) }, entryStyle: Self.mainKinds.contains(kind) ? .dateRight : .stacked, kinds: [kind], interaction: interaction)
    }

    private func tile(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: .rect(cornerRadius: 14))
    }
}
