import PAVECore
import SwiftUI

/// The white panel with a grabber that holds Ayla's vacancy cards.
struct VacancyPanel: View {
    let vacancies: [Vacancy]

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.grabber)
                .frame(width: 52, height: 4)
                .accessibilityHidden(true)
            ForEach(vacancies) { vacancy in
                VacancyCard(vacancy: vacancy)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 26)
        .padding(.bottom, 20)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.25), radius: 0.7)
        }
    }
}

#Preview {
    ScrollView {
        VacancyPanel(vacancies: [
            Vacancy(id: "1", title: "IT-coördinator", company: "Voorbeeld BV", city: "Eindhoven", employment: .fullTime, source: .adzuna),
            Vacancy(id: "2", title: "Junior front-end developer", company: "Studio", city: "Rotterdam", employment: .partTime, source: .adzuna),
        ])
    }
    .background(Color.canvas)
}
