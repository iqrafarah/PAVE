import PAVECore
import SwiftUI

/// Schuin: the richest design. A dark band set at a slant with the name in big capitals and a stripe of colour, the
/// photo over its edge, a row of figures that stand out, and two columns with a timeline.
struct CVTiltLayout: View {
    let draft: ApplicationDraft
    let photo: UIImage?
    let interaction: ApplicationPageInteraction?

    private static let bandHeight: CGFloat = 190
    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }

    /// How many shown entries each part has: real counts from the CV, nothing estimated.
    private var figures: [(Int, String)] {
        cv.visibleSections
            .map { section in (section.entries.filter(\.isVisible).count, ApplyMessages.section(section.kind)) }
            .filter { $0.0 > 0 }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                CVTiltBand(theme: theme, height: Self.bandHeight)
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text((cv.name.isEmpty ? (interaction == nil ? " " : ApplyMessages.name) : cv.name).uppercased())
                            .font(theme.display(32, .black))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        if !cv.headline.isEmpty {
                            Text(cv.headline)
                                .font(theme.body(11, .semibold))
                                .foregroundStyle(theme.tint)
                        }
                        CVContactList(cv: cv, theme: theme, isRow: true, onDark: true, iconColor: theme.tint)
                            .padding(.top, 6)
                    }
                    Spacer(minLength: 0)
                    CVPhotoView(photo: photo, size: 112, ring: .white, ringWidth: 5)
                        .padding(.top, 34)
                }
                .padding(.horizontal, 44)
                .padding(.top, 44)
            }
            .frame(height: Self.bandHeight, alignment: .top)
            .applicationBlock(.personal, interaction, accent: theme.accent)
            .zIndex(1)
            VStack(alignment: .leading, spacing: 22) {
                if !figures.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(figures.enumerated()), id: \.offset) { index, figure in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(figure.0)")
                                    .font(theme.display(30, .black))
                                    .foregroundStyle(theme.accent)
                                Text(figure.1.uppercased())
                                    .font(theme.body(7.5, .bold))
                                    .tracking(1.4)
                                    .foregroundStyle(theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, index == 0 ? 0 : 14)
                            .overlay(alignment: .leading) {
                                if index > 0 { Rectangle().fill(theme.ink.opacity(0.12)).frame(width: 1) }
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                CVProfileBlock(cv: cv, theme: theme, titleStyle: .slash, interaction: interaction)
                HStack(alignment: .top, spacing: 26) {
                    CVSectionsBlock(cv: cv, theme: theme, titleStyle: { _ in .slash }, entryStyle: .timeline, kinds: [.experience, .projects], interaction: interaction, spacing: 20)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 20) {
                        CVSectionsBlock(cv: cv, theme: theme, titleStyle: { _ in .slash }, entryStyle: .stacked, kinds: [.education, .certificates], interaction: interaction, spacing: 20)
                        if !cv.skills.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                CVSectionTitle(title: ApplyMessages.skillsHeading, style: .slash, theme: theme)
                                CVSkillsView(skills: cv.skills, style: .outline, theme: theme)
                            }
                            .applicationBlock(.skills, interaction, accent: theme.accent)
                        }
                    }
                    .padding(14)
                    .frame(width: 190, alignment: .leading)
                    .background(theme.tint.opacity(0.7), in: .rect(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 44)
            .padding(.top, 18)
            .padding(.bottom, 44)
        }
    }
}

/// The dark band of Schuin, its lower edge at a slant, with a stripe of colour along it.
struct CVTiltBand: View {
    let theme: ApplicationTheme
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            SlantedBand(drop: 34).fill(theme.accent).frame(height: height + 8)
            SlantedBand(drop: 34).fill(theme.dark).frame(height: height)
        }
        .frame(height: height + 8, alignment: .top)
        .allowsHitTesting(false)
    }
}

/// A rectangle whose bottom edge runs down from left to right.
nonisolated struct SlantedBand: Shape {
    let drop: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: rect.maxX, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY - drop))
            path.closeSubpath()
        }
    }
}
