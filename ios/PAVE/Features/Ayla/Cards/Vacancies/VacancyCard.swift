import PAVECore
import SwiftUI

/// A vacancy in Ayla's results (Figma frame "Vacatures"). Tapping it opens the vacancy, if it has a link.
struct VacancyCard: View {
    let vacancy: Vacancy
    var tint = Color.cardTintRose

    /// The tints in the order Figma uses them for a list of cards.
    static let tints: [Color] = [.cardTintRose, .cardTintGreen, .cardTintLavender, .cardTintApricot, .cardTintLime]

    var body: some View {
        if let url = vacancy.url {
            Link(destination: url) { content }
                .buttonStyle(.pave)
                .accessibilityHint("Opent de vacature")
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            CompanyMonogram(name: vacancy.company)
                .padding(.top, 11)
            VStack(alignment: .leading, spacing: 0) {
                Text(vacancy.title)
                    .textStyle(.bubble)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
                VStack(alignment: .leading, spacing: 9) {
                    meta(.iconBuilding, [vacancy.company, vacancy.city].compactMap(\.self).joined(separator: " - "))
                    if let employment = employmentText {
                        meta(.iconBriefcase, employment)
                    }
                    if let salary = vacancy.salary {
                        meta(.iconEuro, Self.salaryText(salary))
                    }
                }
                .padding(.top, 13.6)
                if !vacancy.skillGap.isEmpty {
                    skillGap
                        .padding(.top, 14)
                }
            }
            .padding(.trailing, 18)
            .padding(.bottom, 17)
        }
        .padding(.leading, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FigmaCardGradient(tint: tint, start: UnitPoint(x: 0.97, y: 1.08), end: UnitPoint(x: 0.03, y: -0.08)) }
        .clipShape(.rect(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17).strokeBorder(Color.cardBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var employmentText: String? {
        switch vacancy.employment {
        case .fullTime?: "Fulltime"
        case .partTime?: "Part-time"
        default: nil
        }
    }

    private func meta(_ icon: ImageResource, _ text: String) -> some View {
        PaveIconLabel(icon: icon, text: text)
            .padding(.leading, 4.5)
    }

    private var skillGap: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Skill-gap:")
                .textStyle(.label)
                .foregroundStyle(Color.ink)
            ForEach(vacancy.skillGap, id: \.skill) { gap in
                HStack {
                    Text(gap.skill)
                        .textStyle(.gapChip)
                        .foregroundStyle(Color.paveAccent)
                    Spacer()
                    Image(.iconArrowRight)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 11)
                .frame(minHeight: 32)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 7))
            }
        }
    }

    static func salaryText(_ salary: Vacancy.Salary) -> String {
        let range = salary.monthlyRange
        let format = IntegerFormatStyle<Int>().locale(Locale(identifier: "nl_NL"))
        let text = "€\(range.lowerBound.formatted(format)) - €\(range.upperBound.formatted(format)) p/m"
        return salary.isEstimate ? "\(text) (geschat)" : text
    }
}

#Preview {
    VacancyCard(vacancy: Vacancy(
        id: "1", title: "IT-coördinator", company: "Voorbeeld BV", city: "Eindhoven", employment: .fullTime,
        salary: .init(min: 33600, max: 40800, period: .year, isEstimate: false), url: URL(string: "https://www.adzuna.nl"), source: .adzuna,
        skillGap: [.init(skill: "IT-infrastructuur kennis", requirement: "Kennis van netwerken")]
    ))
    .padding(.leading, 26)
    .padding(.trailing, 25)
}
