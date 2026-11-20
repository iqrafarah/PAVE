import PAVECore
import SwiftUI

/// A vacancy in Ayla's results (Figma frame "Vacatures"): who, where and what it pays, a few skills that fit or that
/// you miss, and Bewaren and Vraag Ayla. Tapping the card opens the vacancy in the same panel.
struct VacancyCard: View {
    let vacancy: Vacancy
    var tint = Color.cardTintRose
    var isSaved = false
    var onOpen: (() -> Void)?
    /// Nil when vacancies cannot be kept (yet).
    var onToggleSave: (() -> Void)?
    var onAsk: (() -> Void)?

    /// The tints in the order Figma uses them for a list of cards.
    static let tints: [Color] = [.cardTintRose, .cardTintGreen, .cardTintLavender, .cardTintApricot, .cardTintLime]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { onOpen?() } label: {
                VStack(alignment: .leading, spacing: 14) {
                    VacancyHeader(vacancy: vacancy, showsChevron: onOpen != nil)
                    if !vacancy.matches.isEmpty || !vacancy.skillGap.isEmpty {
                        VacancySkillChips(matches: vacancy.matches, gaps: vacancy.skillGap)
                    }
                }
                .padding(.trailing, 18)
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .disabled(onOpen == nil)
            .accessibilityHint("Opent de vacature")

            VacancyActions(vacancy: vacancy, isSaved: isSaved, onToggleSave: onToggleSave, onAsk: onAsk)
                .padding(.trailing, 13)
        }
        .padding(.leading, 13)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FigmaCardGradient(tint: tint, start: UnitPoint(x: 0.97, y: 1.08), end: UnitPoint(x: 0.03, y: -0.08)) }
        .clipShape(.rect(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Color.cardBorder, lineWidth: 1) }
    }
}

#Preview {
    VacancyCard(
        vacancy: Vacancy(
            id: "1", title: "IT-coördinator", company: "Voorbeeld BV", city: "Eindhoven", employment: .fullTime,
            salary: .init(min: 33600, max: 40800, period: .year, isEstimate: false), url: URL(string: "https://www.adzuna.nl"), source: .adzuna,
            matches: [.init(skill: "React", requirement: "Ervaring met React is een pre")],
            skillGap: [.init(skill: "Scrum-certificaat", requirement: "Je hebt een Scrum-certificaat (PSM I)")]
        ),
        onOpen: {}, onToggleSave: {}, onAsk: {}
    )
    .padding(.horizontal, 25)
}
