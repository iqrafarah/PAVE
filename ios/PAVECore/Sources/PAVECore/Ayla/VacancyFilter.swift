import Foundation

/// Narrowing down and ordering the vacancies Ayla found: by place, hours and whether the company hires directly or is
/// an agency, and by how well they match.
public struct VacancyFilter: Equatable, Sendable {
    public enum Order: String, CaseIterable, Sendable { case asFound, bestMatch }
    public enum Employer: String, CaseIterable, Sendable { case any, direct, agency }

    public var order = Order.asFound
    public var city: String?
    public var employment: Vacancy.Employment?
    public var employer = Employer.any

    public init(order: Order = .asFound, city: String? = nil, employment: Vacancy.Employment? = nil, employer: Employer = .any) {
        self.order = order
        self.city = city
        self.employment = employment
        self.employer = employer
    }

    /// How many filters narrow the list; the order does not count.
    public var activeCount: Int { [city != nil, employment != nil, employer != .any].filter { $0 }.count }

    public func apply(to vacancies: [Vacancy]) -> [Vacancy] {
        let kept = vacancies.filter { vacancy in
            if let city, vacancy.city?.localizedCaseInsensitiveCompare(city) != .orderedSame { return false }
            if let employment, vacancy.employment != employment { return false }
            switch employer {
            case .any: return true
            case .direct: return !VacancyAgency.isAgency(vacancy.company)
            case .agency: return VacancyAgency.isAgency(vacancy.company)
            }
        }
        guard order == .bestMatch else { return kept }
        // Stable: equal matches keep the order Ayla found them in.
        return kept.enumerated()
            .sorted { ($0.element.matchPercent ?? -1, -$0.offset) > ($1.element.matchPercent ?? -1, -$1.offset) }
            .map(\.element)
    }

    /// The places in these vacancies, for the filter, most common first.
    public static func cities(in vacancies: [Vacancy]) -> [String] {
        let counts = vacancies.compactMap { $0.city?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }
}

extension Vacancy {
    /// Of the skills Ayla compared, the share that fits, as a whole percentage; nil when she compared none. An
    /// estimate from a piece of the vacancy text, not a judgement.
    public var matchPercent: Int? {
        let total = matches.count + skillGap.count
        guard total > 0 else { return nil }
        return Int((Double(matches.count) / Double(total) * 100).rounded())
    }
}

/// Recruitment and temp agencies in the Netherlands, recognised by their name. Only a guess from the name, and said so
/// where it is shown.
public enum VacancyAgency {
    static let names = [
        "randstad", "tempo-team", "tempo team", "adecco", "youngcapital", "young capital", "start people", "manpower",
        "olympia", "unique", "brunel", "hays", "michael page", "page personnel", "yacht", "luba", "tentoo", "covebo",
        "otto work", "timing", "synergie", "maandag", "uitzendbureau", "detacheer", "detachering", "recruitment", "werving",
        "staffing", "interim", "jobsupport", "tmi", "level one", "headfirst", "computer futures", "harvey nash",
    ]

    public static func isAgency(_ company: String) -> Bool {
        let name = company.lowercased()
        return names.contains { name.contains($0) }
    }
}
