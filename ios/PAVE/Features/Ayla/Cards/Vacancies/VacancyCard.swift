import PAVECore
import SwiftUI

/// A vacancy in Ayla's results (Figma frame "Vacatures"): who, where and what it pays, how many of the skills she
/// found fit you, and the bookmark in the corner. Tapping the card opens the vacancy in the same panel.
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

    private var hasFit: Bool { !vacancy.matches.isEmpty || !vacancy.skillGap.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { onOpen?() } label: {
                VStack(alignment: .leading, spacing: 14) {
                    VacancyHeader(vacancy: vacancy)
                        // Room for the bookmark in the corner.
                        .padding(.trailing, onToggleSave == nil ? 18 : 40)
                    if hasFit {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(AylaMessages.vacancyFitCount(vacancy.matches.count, of: vacancy.matches.count + vacancy.skillGap.count))
                                    .textStyle(.caption)
                                    .foregroundStyle(Color.ink)
                                Spacer(minLength: 0)
                                if let percent = vacancy.matchPercent {
                                    VacancyMatchBadge(percent: percent)
                                }
                            }
                            VacancySkillChips(matches: vacancy.matches, gaps: vacancy.skillGap)
                        }
                        .padding(.trailing, 18)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .disabled(onOpen == nil)
            .accessibilityHint("Opent de vacature")

            if let onAsk {
                VacancyAskButton(action: onAsk)
            }
        }
        .padding(.leading, 13)
        .padding(.bottom, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FigmaCardGradient(tint: tint, start: UnitPoint(x: 0.97, y: 1.08), end: UnitPoint(x: 0.03, y: -0.08)) }
        .clipShape(.rect(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Color.cardBorder, lineWidth: 1) }
        .overlay(alignment: .topTrailing) {
            if let onToggleSave {
                VacancySaveButton(isSaved: isSaved, action: onToggleSave)
                    .padding(.top, 6)
                    .padding(.trailing, 6)
            }
        }
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
