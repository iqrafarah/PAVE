import Foundation

/// A card in a reply. A type this app does not know yet decodes as `.unknown`
/// and is skipped, so the server can add cards without breaking older apps.
public enum AylaBlock: Codable, Equatable, Sendable {
    case vaultSelection([CategoryCount])
    case vacancies([Vacancy])
    case skillSuggestions(itemId: String, skills: [SkillSuggestion])
    case cv(CurriculumVitae)
    case unknown(type: String)

    public struct CategoryCount: Codable, Equatable, Sendable {
        public var category: VaultCategory
        public var count: Int

        public init(category: VaultCategory, count: Int) {
            self.category = category
            self.count = count
        }
    }

    public struct SkillSuggestion: Codable, Equatable, Sendable {
        public var name: String
        public var reason: String

        public init(name: String, reason: String) {
            self.name = name
            self.reason = reason
        }
    }

    public struct CurriculumVitae: Codable, Equatable, Sendable {
        public struct Experience: Codable, Equatable, Sendable {
            public var title: String
            public var organisation: String
            public var period: String
            public var description: String?

            public init(title: String, organisation: String, period: String, description: String? = nil) {
                self.title = title
                self.organisation = organisation
                self.period = period
                self.description = description
            }
        }

        public var profile: String
        public var experience: [Experience]
        public var skills: [String]

        public init(profile: String, experience: [Experience], skills: [String]) {
            self.profile = profile
            self.experience = experience
            self.skills = skills
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, categories, items, itemId, skills, profile, experience
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "vaultSelection":
            self = .vaultSelection(try container.decode([CategoryCount].self, forKey: .categories))
        case "vacancies":
            self = .vacancies(try container.decode([Vacancy].self, forKey: .items))
        case "skillSuggestions":
            self = .skillSuggestions(
                itemId: try container.decode(String.self, forKey: .itemId),
                skills: try container.decode([SkillSuggestion].self, forKey: .skills)
            )
        case "cv":
            self = .cv(CurriculumVitae(
                profile: try container.decode(String.self, forKey: .profile),
                experience: try container.decode([CurriculumVitae.Experience].self, forKey: .experience),
                skills: try container.decode([String].self, forKey: .skills)
            ))
        default:
            self = .unknown(type: type)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .vaultSelection(let categories):
            try container.encode("vaultSelection", forKey: .type)
            try container.encode(categories, forKey: .categories)
        case .vacancies(let items):
            try container.encode("vacancies", forKey: .type)
            try container.encode(items, forKey: .items)
        case .skillSuggestions(let itemId, let skills):
            try container.encode("skillSuggestions", forKey: .type)
            try container.encode(itemId, forKey: .itemId)
            try container.encode(skills, forKey: .skills)
        case .cv(let cv):
            try container.encode("cv", forKey: .type)
            try container.encode(cv.profile, forKey: .profile)
            try container.encode(cv.experience, forKey: .experience)
            try container.encode(cv.skills, forKey: .skills)
        case .unknown(let type):
            try container.encode(type, forKey: .type)
        }
    }
}
