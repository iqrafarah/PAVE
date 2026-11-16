import PAVECore
import SwiftUI

/// Ayla's vacancy results, for the bottom panel on iPhone and the side column on iPhone Duo and iPad.
struct VacancyList: View {
    let vacancies: [Vacancy]

    var body: some View {
        LazyVStack(spacing: 18) {
            ForEach(Array(vacancies.enumerated()), id: \.element.id) { index, vacancy in
                VacancyCard(vacancy: vacancy, tint: VacancyCard.tints[index % VacancyCard.tints.count])
            }
            if vacancies.contains(where: { $0.source == .adzuna }) {
                Text("Vacatures via Adzuna")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
    }
}
