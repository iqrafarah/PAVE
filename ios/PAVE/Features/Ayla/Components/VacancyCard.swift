import PAVECore
import SwiftUI

struct VacancyCard: View {
    let vacancy: Vacancy

    private static let tints: [Color] = [.cardTintRose, .cardTintGreen, .cardTintLavender, .cardTintApricot, .cardTintLime]

    private var tint: Color {
        let sum = vacancy.company.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.tints[sum % Self.tints.count]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CompanyMonogram(name: vacancy.company)
            VStack(alignment: .leading, spacing: 8) {
                Text(vacancy.title)
                    .textStyle(.bubble)
                    .foregroundStyle(Color.ink)
                    .padding(.top, 5)
                    .padding(.bottom, 4)
                    .fixedSize(horizontal: false, vertical: true)
                meta(.iconBuilding, [vacancy.company, vacancy.city].compactMap(\.self).joined(separator: " - "))
                if let employment = employmentText {
                    meta(.iconBriefcase, employment)
                }
                if let salary = vacancy.salary {
                    meta(.iconEuro, Self.salaryText(salary))
                }
                if !vacancy.skillGap.isEmpty {
                    skillGap
                }
                footer
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(stops: [.init(color: tint, location: 0), .init(color: .white, location: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
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
            .padding(.leading, 5)
    }

    private var skillGap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Skill-gap:")
                .textStyle(.label)
                .foregroundStyle(Color.ink)
            ForEach(vacancy.skillGap, id: \.skill) { gap in
                HStack {
                    Text(gap.skill)
                        .textStyle(.gapChip)
                        .foregroundStyle(Color.brandGreen)
                    Spacer()
                    Image(.iconArrowRight)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 11)
                .frame(minHeight: 32)
                .background(Color.surfaceTint, in: .rect(cornerRadius: 7))
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            Text(vacancy.source == .adzuna ? "Via Adzuna" : "Voorbeeldvacature")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
            Spacer()
            if let url = vacancy.url {
                Link(destination: url) {
                    Text("Bekijk vacature")
                        .textStyle(.gapChip)
                        .foregroundStyle(Color.brandGreen)
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(.top, 2)
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
        salary: .init(min: 33600, max: 40800, period: .year, isEstimate: true), url: URL(string: "https://www.adzuna.nl"), source: .adzuna,
        skillGap: [.init(skill: "IT-infrastructuur", requirement: "Kennis van netwerken")]
    ))
    .padding()
}
