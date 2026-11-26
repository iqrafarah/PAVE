import Foundation

/// An employer at a job fair, as their QR code opens it: who they are, their stand and their vacancies. Some are
/// fictional and shown as such; real ones carry real vacancies, read on the day they were added (`addedAt`).
public struct FairEmployer: Identifiable, Equatable, Sendable, Decodable {
    public var id: String { slug }
    public let slug: String
    public let name: String
    public let city: String?
    public let about: String
    public let stand: String?
    public let website: String?
    public let vacancies: [Vacancy]
    public let isExample: Bool
    /// When it was put on the fair: for a real employer, the day its vacancies were read.
    public let addedAt: Date?

    enum CodingKeys: String, CodingKey {
        case slug, name, city, about, stand, website, vacancies
        case isExample = "is_example"
        case addedAt = "created_at"
    }

    public init(slug: String, name: String, city: String? = nil, about: String, stand: String? = nil, website: String? = nil, vacancies: [Vacancy] = [], isExample: Bool = true, addedAt: Date? = nil) {
        self.addedAt = addedAt
        self.slug = slug
        self.name = name
        self.city = city
        self.about = about
        self.stand = stand
        self.website = website
        self.vacancies = vacancies
        self.isExample = isExample
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        slug = try values.decode(String.self, forKey: .slug)
        name = try values.decode(String.self, forKey: .name)
        city = try values.decodeIfPresent(String.self, forKey: .city)
        about = try values.decode(String.self, forKey: .about)
        stand = try values.decodeIfPresent(String.self, forKey: .stand)
        website = try values.decodeIfPresent(String.self, forKey: .website)
        // A vacancy that does not read is left out, not the employer.
        vacancies = ((try? values.decode([FailableVacancy].self, forKey: .vacancies)) ?? []).compactMap(\.vacancy)
        isExample = (try? values.decode(Bool.self, forKey: .isExample)) ?? true
        addedAt = (try? values.decode(String.self, forKey: .addedAt)).flatMap { text in
            (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)) ?? (try? Date.ISO8601FormatStyle().parse(text))
        }
    }

    private struct FailableVacancy: Decodable {
        let vacancy: Vacancy?
        init(from decoder: any Decoder) throws { vacancy = try? Vacancy(from: decoder) }
    }
}
