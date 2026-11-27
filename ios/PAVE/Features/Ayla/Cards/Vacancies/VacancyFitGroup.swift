import PAVECore
import SwiftUI

/// What fits, or what you still miss, as one group: each skill with the line of the vacancy it comes from, so you can
/// check it. A missing skill asks Ayla how to get it.
struct VacancyFitGroup: View {
    let links: [Vacancy.RequirementLink]
    let isGap: Bool
    var onAsk: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(links, id: \.skill) { link in
                VacancyRequirementRow(link: link, isGap: isGap, onAsk: onAsk.map { ask in { ask(link.skill) } })
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isGap ? Color.panel : Color.paveSurfaceTint, in: .rect(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(isGap ? Color.cardBorder : .clear, lineWidth: 1) }
    }
}
