import PAVECore
import SwiftUI

/// Who, where and what it pays (Figma frame "Vacatures"), at the top of a vacancy card and of the vacancy itself.
struct VacancyHeader: View {
    let vacancy: Vacancy
    /// A card that opens the vacancy shows where to tap.
    var showsChevron = false
    /// The vacancy itself also says when the source last saw it.
    var showsPosted = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // "Via werkzoeken.nl" (no company known) shows the letter of the site, not of "Via".
            CompanyMonogram(name: vacancy.company.hasPrefix("Via ") ? String(vacancy.company.dropFirst(4)) : vacancy.company)
                .padding(.top, 11)
            VStack(alignment: .leading, spacing: 0) {
                Text(vacancy.title)
                    .textStyle(.bubble)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
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
                    if showsPosted, let posted = vacancy.postedAt.flatMap(AylaMessages.vacancyPosted) {
                        meta(.iconVaultCalendarOutline, posted)
                    }
                }
                .padding(.top, 13.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 20)
                    .accessibilityHidden(true)
            }
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
            .multilineTextAlignment(.leading)
            .padding(.leading, 4.5)
    }

    static func salaryText(_ salary: Vacancy.Salary) -> String {
        let range = salary.monthlyRange
        let format = IntegerFormatStyle<Int>().locale(Locale(identifier: "nl_NL"))
        let text = range.lowerBound == range.upperBound
            ? "€\(range.lowerBound.formatted(format)) p/m"
            : "€\(range.lowerBound.formatted(format)) - €\(range.upperBound.formatted(format)) p/m"
        return salary.isEstimate ? "\(text) (geschat)" : text
    }
}
