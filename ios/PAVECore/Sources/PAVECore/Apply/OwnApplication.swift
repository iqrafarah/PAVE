import Foundation

extension Vacancy.Source {
    /// A vacancy the user entered: one they found elsewhere, or an open application to a company.
    public static let own = Self(rawValue: "own")
}

extension Vacancy {
    /// The title of an application to a company without a vacancy.
    public static let openApplicationTitle = "Open sollicitatie"

    public var isOpenApplication: Bool { source == .own && title == Self.openApplicationTitle }
}

/// What the user fills in to apply somewhere that PAVE did not find: the company, and the job when there is one.
public struct OwnApplication: Equatable, Sendable {
    public var company = ""
    /// Empty for an open application.
    public var title = ""
    public var city = ""
    public var link = ""
    /// The vacancy text as pasted, so the letter and Ayla can follow it.
    public var text = ""

    public init(company: String = "", title: String = "", city: String = "", link: String = "", text: String = "") {
        self.company = company
        self.title = title
        self.city = city
        self.link = link
        self.text = text
    }

    public enum Problem: Equatable, Sendable { case noCompany, badLink }

    public var problem: Problem? {
        if company.trimmed.isEmpty { return .noCompany }
        if !link.trimmed.isEmpty, url == nil { return .badLink }
        return nil
    }

    /// A link as typed, with https added when it was left off.
    var url: URL? {
        let typed = link.trimmed
        guard !typed.isEmpty, !typed.contains(" ") else { return nil }
        let full = typed.lowercased().hasPrefix("http") ? typed : "https://\(typed)"
        guard let url = URL(string: full), let host = url.host(), host.contains(".") else { return nil }
        return url
    }

    public func vacancy(id: String = "own-\(UUID().uuidString.lowercased())") -> Vacancy {
        Vacancy(
            id: id,
            title: title.trimmed.isEmpty ? Vacancy.openApplicationTitle : title.trimmed,
            company: company.trimmed,
            city: city.trimmed.isEmpty ? nil : city.trimmed,
            url: url,
            source: .own,
            summary: text.trimmed.isEmpty ? nil : String(text.trimmed.prefix(2000))
        )
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
