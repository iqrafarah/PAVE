import PAVECore
import SwiftUI

/// At a glance on a card: a few skills that fit (filled) and that you still miss (outlined). The vacancy itself shows
/// each with the line of the vacancy it comes from.
struct VacancySkillChips: View {
    let matches: [Vacancy.RequirementLink]
    let gaps: [Vacancy.RequirementLink]
    var limit = 3

    private var shown: [(skill: String, isGap: Bool)] {
        (matches.map { ($0.skill, false) } + gaps.map { ($0.skill, true) }).prefix(limit).map(\.self)
    }

    private var hidden: Int { matches.count + gaps.count - shown.count }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(shown, id: \.skill) { chip in
                HStack(spacing: 5) {
                    Image(chip.isGap ? .iconPlus : .iconCheck)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 11, height: 11)
                        .accessibilityHidden(true)
                    Text(chip.skill)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: 220)
                .textStyle(.caption)
                .foregroundStyle(chip.isGap ? Color.ink : Color.paveAccent)
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(chip.isGap ? Color.panel : Color.paveSurfaceTint, in: .capsule)
                .overlay { Capsule().strokeBorder(chip.isGap ? Color.cardBorder : .clear, lineWidth: 1) }
            }
            if hidden > 0 {
                Text("+\(hidden)")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 28)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        [
            matches.isEmpty ? nil : "\(AylaMessages.vacancyFits): \(matches.map(\.skill).formatted(.list(type: .and)))",
            gaps.isEmpty ? nil : "\(AylaMessages.vacancyMissing): \(gaps.map(\.skill).formatted(.list(type: .and)))",
        ]
        .compactMap(\.self)
        .joined(separator: ". ")
    }
}

#Preview {
    VacancySkillChips(
        matches: [.init(skill: "Scrum", requirement: ""), .init(skill: "React", requirement: "")],
        gaps: [.init(skill: "Scrum-certificaat", requirement: ""), .init(skill: "Azure", requirement: "")]
    )
    .padding()
}
