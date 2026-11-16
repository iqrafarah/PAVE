import Foundation

public struct Vacancy: Codable, Equatable, Sendable, Identifiable {
    public struct Employment: AylaValue {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let fullTime = Self(rawValue: "fullTime")
        public static let partTime = Self(rawValue: "partTime")
    }

    public struct Source: AylaValue {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        /// A fictional vacancy. The apps label it as an example.
        public static let example = Self(rawValue: "example")
        public static let adzuna = Self(rawValue: "adzuna")
    }

    public struct Salary: Codable, Equatable, Sendable {
        public enum Period: String, Codable, Sendable {
            case month
            case year
        }

        public var min: Double
        public var max: Double
        public var period: Period
        public var currency: String
        public var isEstimate: Bool

        public init(min: Double, max: Double, period: Period, currency: String = "EUR", isEstimate: Bool) {
            self.min = min
            self.max = max
            self.period = period
            self.currency = currency
            self.isEstimate = isEstimate
        }

        /// The apps always show a salary per month, rounded to whole euros.
        public var monthlyRange: ClosedRange<Int> {
            let divisor: Double = period == .year ? 12 : 1
            let low = Int((min / divisor).rounded())
            let high = Int((max / divisor).rounded())
            return Swift.min(low, high)...Swift.max(low, high)
        }
    }

    /// A skill and the requirement of the vacancy it comes from, so the user can check it.
    public struct RequirementLink: Codable, Equatable, Sendable {
        public var skill: String
        public var requirement: String

        public init(skill: String, requirement: String) {
            self.skill = skill
            self.requirement = requirement
        }
    }

    public var id: String
    public var title: String
    public var company: String
    public var city: String?
    public var employment: Employment?
    public var salary: Salary?
    public var logoUrl: URL?
    public var url: URL?
    public var source: Source
    public var matches: [RequirementLink]
    public var skillGap: [RequirementLink]

    public init(
        id: String,
        title: String,
        company: String,
        city: String? = nil,
        employment: Employment? = nil,
        salary: Salary? = nil,
        logoUrl: URL? = nil,
        url: URL? = nil,
        source: Source,
        matches: [RequirementLink] = [],
        skillGap: [RequirementLink] = []
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.city = city
        self.employment = employment
        self.salary = salary
        self.logoUrl = logoUrl
        self.url = url
        self.source = source
        self.matches = matches
        self.skillGap = skillGap
    }
}
