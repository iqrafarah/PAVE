import Foundation

/// What Ayla found on the web about a company, for someone about to apply: what it does, how big it is, where it
/// works and a few facts that matter for applying, each claim backed by the pages it came from.
public struct CompanyAbout: Codable, Equatable, Sendable {
    public struct Fact: Codable, Equatable, Sendable {
        public var label: String
        public var text: String
        public init(label: String, text: String) {
            self.label = label
            self.text = text
        }
    }

    public struct Source: Codable, Equatable, Sendable {
        public var title: String
        public var url: URL
        public init(title: String, url: URL) {
            self.title = title
            self.url = url
        }
    }

    public var about: String
    public var sector: String?
    public var size: String?
    public var locations: [String]
    public var website: String?
    public var facts: [Fact]
    public var sources: [Source]
    /// When it was looked up, shown so it is clear how old it is.
    public var foundAt: Date

    public init(about: String, sector: String? = nil, size: String? = nil, locations: [String] = [], website: String? = nil, facts: [Fact] = [], sources: [Source], foundAt: Date = .now) {
        self.about = about
        self.sector = sector
        self.size = size
        self.locations = locations
        self.website = website
        self.facts = facts
        self.sources = sources
        self.foundAt = foundAt
    }

    /// The company's own site as a link, only for a plain domain.
    public var websiteURL: URL? {
        guard let website, website.range(of: #"^[a-z0-9-]+(\.[a-z0-9-]+)+$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "https://\(website)")
    }
}

/// Looked-up companies kept on this device for a month, so asking again costs nothing and works offline.
public struct CompanyAboutStore: Sendable {
    private let folder: URL
    public static let keepsFor: TimeInterval = 30 * 86_400

    public init(folder: URL = URL.cachesDirectory.appending(path: "CompanyAbout", directoryHint: .isDirectory)) {
        self.folder = folder
    }

    public static func key(company: String, city: String?) -> String {
        "\(company)|\(city ?? "")".lowercased().trimmingCharacters(in: .whitespaces)
    }

    public func load(company: String, city: String?, now: Date = .now) -> CompanyAbout? {
        guard let data = try? Data(contentsOf: file(company, city)),
              let about = try? JSONDecoder.iso.decode(CompanyAbout.self, from: data),
              now.timeIntervalSince(about.foundAt) < Self.keepsFor
        else { return nil }
        return about
    }

    public func save(_ about: CompanyAbout, company: String, city: String?) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? JSONEncoder.iso.encode(about) { try? data.write(to: file(company, city), options: .atomic) }
    }

    private func file(_ company: String, _ city: String?) -> URL {
        let name = Self.key(company: company, city: city).unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }.joined()
        return folder.appending(path: "\(name.prefix(120)).json")
    }
}

private extension JSONDecoder {
    static var iso: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var iso: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
