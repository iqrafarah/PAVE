import PAVECore
import SwiftUI

struct VacancyCard: View {
    let vacancy: Vacancy

    private static let tints: [Color] = [
        Color(red: 0xF7 / 255, green: 0xC8 / 255, blue: 0xCC / 255),
        Color(red: 0xDD / 255, green: 0xEC / 255, blue: 0xCF / 255),
        Color(red: 0xE7 / 255, green: 0xDD / 255, blue: 0xF7 / 255),
        Color(red: 0xFF / 255, green: 0xE4 / 255, blue: 0xC1 / 255),
        Color(red: 0xF0 / 255, green: 0xF9 / 255, blue: 0xCD / 255),
    ]

    private var tint: Color {
        let sum = vacancy.company.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.tints[sum % Self.tints.count]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            monogram
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

    private var monogram: some View {
        Text(vacancy.company.prefix(1).uppercased())
            .font(.custom("InterVariable-Bold", size: 26, relativeTo: .title2))
            .foregroundStyle(Color.brandGreen)
            .frame(width: 64, height: 64)
            .background(Color.white, in: .circle)
            .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
            .accessibilityHidden(true)
    }

    private var employmentText: String? {
        switch vacancy.employment {
        case .fullTime?: "Fulltime"
        case .partTime?: "Part-time"
        default: nil
        }
    }

    private func meta(_ icon: ImageResource, _ text: String) -> some View {
        HStack(spacing: 9) {
            Image(icon)
                .renderingMode(.template)
                .foregroundStyle(Color.inkMuted)
                .frame(width: 17, height: 17)
                .accessibilityHidden(true)
            Text(text)
                .textStyle(.meta)
                .foregroundStyle(Color.inkMuted)
        }
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

struct VacancyPanel: View {
    let vacancies: [Vacancy]

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color(red: 0xE0 / 255, green: 0xE2 / 255, blue: 0xE2 / 255))
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
            Vacancy(id: "1", title: "IT-coördinator", company: "Voorbeeld BV", city: "Eindhoven", employment: .fullTime,
                    salary: .init(min: 33600, max: 40800, period: .year, isEstimate: true), url: URL(string: "https://www.adzuna.nl"), source: .adzuna,
                    skillGap: [.init(skill: "IT-infrastructuur", requirement: "Kennis van netwerken")]),
            Vacancy(id: "2", title: "Junior front-end developer", company: "Studio", city: "Rotterdam", employment: .partTime, source: .adzuna),
        ])
    }
    .background(Color.canvas)
}
