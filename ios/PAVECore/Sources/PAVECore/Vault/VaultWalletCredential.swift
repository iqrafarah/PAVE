import Foundation

/// One credential in the demo wallet ("Uit je wallet"): evidence a school or employer already signed, which comes into
/// the vault confirmed. The wallet is made up per account by the `vault-wallet` function; nothing is real.
public struct VaultWalletCredential: Identifiable, Equatable, Sendable {
    /// The issuer's logo from its own site, as "Laat Ayla invullen" finds it.
    public struct Logo: Equatable, Sendable {
        public let data: Data
        public let mimeType: String

        public init(data: Data, mimeType: String) {
            self.data = data
            self.mimeType = mimeType
        }

        /// The file name it gets as the logo of the item in the vault.
        public var fileName: String {
            switch mimeType {
            case "image/jpeg": "logo.jpg"
            case "image/webp": "logo.webp"
            case "image/gif": "logo.gif"
            default: "logo.png"
            }
        }
    }

    public let id: String
    public let category: VaultCategory
    /// The kind of credential, such as "Open Badge", "Diploma" or "Werkgeversverklaring".
    public let format: String
    public let title: String
    public let issuer: String
    public let place: String?
    public let issuedOn: VaultDay?
    public let startDate: VaultDay?
    public let endDate: VaultDay?
    public let isCurrent: Bool
    public let description: String?
    public let skills: [String]
    /// Already taken into the vault.
    public let imported: Bool
    public let logo: Logo?

    public init(
        id: String,
        category: VaultCategory,
        format: String,
        title: String,
        issuer: String,
        place: String? = nil,
        issuedOn: VaultDay? = nil,
        startDate: VaultDay? = nil,
        endDate: VaultDay? = nil,
        isCurrent: Bool = false,
        description: String? = nil,
        skills: [String] = [],
        imported: Bool = false,
        logo: Logo? = nil
    ) {
        self.id = id
        self.category = category
        self.format = format
        self.title = title
        self.issuer = issuer
        self.place = place
        self.issuedOn = issuedOn
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
        self.description = description
        self.skills = skills
        self.imported = imported
        self.logo = logo
    }

    /// "mrt 2025", or "feb 2025 – jul 2025" and "sep 2023 – nu" for a period.
    public var when: String? {
        if let issuedOn { return issuedOn.monthAndYear }
        guard let startDate else { return nil }
        if isCurrent { return "\(startDate.monthAndYear) – nu" }
        return endDate.map { "\(startDate.monthAndYear) – \($0.monthAndYear)" } ?? startDate.monthAndYear
    }
}

extension VaultWalletCredential: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, category, format, title, issuer, place, issuedOn, startDate, endDate, isCurrent, description, skills, imported, logo
    }

    private struct LogoRow: Decodable {
        let data: String
        let mimeType: String
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let day = { (key: CodingKeys) in try container.decodeIfPresent(String.self, forKey: key).flatMap(VaultDay.init) }
        self.init(
            id: try container.decode(String.self, forKey: .id),
            category: (try? container.decode(VaultCategory.self, forKey: .category)) ?? .other,
            format: try container.decodeIfPresent(String.self, forKey: .format) ?? "",
            title: try container.decode(String.self, forKey: .title),
            issuer: try container.decode(String.self, forKey: .issuer),
            place: try container.decodeIfPresent(String.self, forKey: .place),
            issuedOn: try day(.issuedOn),
            startDate: try day(.startDate),
            endDate: try day(.endDate),
            isCurrent: try container.decodeIfPresent(Bool.self, forKey: .isCurrent) ?? false,
            description: try container.decodeIfPresent(String.self, forKey: .description),
            skills: try container.decodeIfPresent([String].self, forKey: .skills) ?? [],
            imported: try container.decodeIfPresent(Bool.self, forKey: .imported) ?? false,
            logo: (try? container.decodeIfPresent(LogoRow.self, forKey: .logo)).flatMap { row in
                Data(base64Encoded: row.data).map { Logo(data: $0, mimeType: row.mimeType) }
            }
        )
    }
}
