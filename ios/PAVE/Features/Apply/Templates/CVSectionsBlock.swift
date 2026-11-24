import PAVECore
import SwiftUI

/// The parts of the CV with their entries, in the order the user chose; `kinds` limits it to some, for a design with
/// two columns.
struct CVSectionsBlock: View {
    let cv: CVContent
    let theme: ApplicationTheme
    let titleStyle: (CVSection.Kind) -> CVSectionTitle.Style
    let entryStyle: CVEntryView.Style
    var kinds: Set<CVSection.Kind> = Set(CVSection.Kind.allCases)
    var interaction: ApplicationPageInteraction?
    var spacing: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(cv.visibleSections.filter { kinds.contains($0.kind) }) { section in
                let entries = section.entries.filter(\.isVisible)
                VStack(alignment: .leading, spacing: entryStyle == .timeline ? 8 : 10) {
                    CVSectionTitle(title: ApplyMessages.section(section.kind), style: titleStyle(section.kind), theme: theme)
                    VStack(alignment: .leading, spacing: entryStyle == .timeline ? 0 : 10) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            CVEntryView(entry: entry, style: entryStyle, theme: theme, isLast: index == entries.count - 1)
                                .applicationBlock(.entry(entry.id), interaction, accent: theme.accent)
                        }
                    }
                }
            }
        }
    }

    /// The icon of a part, for designs that show one before the title.
    static func icon(_ kind: CVSection.Kind) -> ImageResource {
        switch kind {
        case .experience: .iconBriefcaseOutline
        case .education: .iconAcademicCapOutline
        case .certificates: .iconTrophyOutline
        case .projects: .iconRocketLaunchOutline
        }
    }
}
