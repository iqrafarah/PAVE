import Foundation

/// A study or course Ayla found on the web, with the page of the school it is on. Only what that page says: the level,
/// place and length are left out when it does not say them.
public struct AylaEducation: Codable, Equatable, Hashable, Sendable, Identifiable {
    public enum Level: String, Codable, Sendable {
        case mbo, hbo, wo, cursus, overig
    }

    public var id: String
    public var name: String
    public var school: String
    public var level: Level?
    public var city: String?
    /// As the page says it, such as "4 jaar" or "8 weken".
    public var duration: String?
    public var url: URL
    public var summary: String?

    /// The summary as words to read: a page's layout marks ("## Kop > tekst", "**vet**") are not shown.
    public var readableSummary: String? {
        guard let summary else { return nil }
        let text = summary
            .replacing(#/(^|\s)#{1,6}\s+/#) { $0.output.1 }
            .replacing(#/\*\*|__|`/#, with: "")
            .replacing(#/\s[>|]\s/#, with: ". ")
            .replacing(#/\s+/#, with: " ")
            .trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    public init(id: String, name: String, school: String, level: Level? = nil, city: String? = nil, duration: String? = nil, url: URL, summary: String? = nil) {
        self.id = id
        self.name = name
        self.school = school
        self.level = level
        self.city = city
        self.duration = duration
        self.url = url
        self.summary = summary
    }

    private enum CodingKeys: String, CodingKey { case id, name, school, level, city, duration, url, summary }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        school = try container.decode(String.self, forKey: .school)
        // A level this app does not know yet is left out rather than losing the whole card.
        level = (try? container.decodeIfPresent(String.self, forKey: .level)).flatMap { $0.flatMap(Level.init(rawValue:)) }
        city = try container.decodeIfPresent(String.self, forKey: .city)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        url = try container.decode(URL.self, forKey: .url)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
    }

    /// "HBO", "Cursus"; nothing for a level that says little.
    public var levelName: String? {
        switch level {
        case .mbo?, .hbo?, .wo?: level?.rawValue.uppercased()
        case .cursus?: "Cursus"
        case .overig?, nil: nil
        }
    }

    /// Level, place and length, as far as the page says them.
    public var details: [String] { [levelName, city, duration].compactMap { $0 } }

    /// The key a plan step keeps the page under, so the step can open it.
    public static let urlKey = "educationURL"
    public static let idKey = "educationID"

    /// The step it becomes in a plan: look into it, with the page at hand.
    public var planStep: PavePlanStep {
        PavePlanStep(
            title: PavePlan.cleanName("\(name) bij \(school) bekijken") ?? name,
            summary: details.joined(separator: " · "),
            kind: .research,
            metadata: [Self.urlKey: url.absoluteString, Self.idKey: id]
        )
    }
}

/// What Ayla searched for, so it can be shown and searched again.
public struct EducationSearch: Codable, Equatable, Sendable {
    public var what: String
    public var `where`: String

    public init(what: String, where place: String) {
        self.what = what
        self.where = place
    }
}
