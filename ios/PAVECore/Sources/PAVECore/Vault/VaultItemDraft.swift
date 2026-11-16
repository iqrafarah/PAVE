import Foundation

/// What you fill in when you add or change an item. New items always start as your own and not yet confirmed.
public struct VaultItemDraft: Equatable, Sendable {
    public enum Problem: Equatable, Sendable {
        case missingTitle
        case titleTooLong
        case endBeforeStart
        case descriptionTooLong
    }

    public var category: VaultCategory
    public var title = ""
    public var description = ""
    public var organisationName = ""
    public var organisationLocation = ""
    public var startDate: VaultDay?
    public var endDate: VaultDay?
    public var issuedOn: VaultDay?
    public var isCurrent = false
    /// The folders the item goes in; the first is also stored in `folder_id` for older clients.
    public var folderIDs: [String] = []
    /// A period from a start to an end, or one date. Nil follows the category: a period for experience, one date for a
    /// diploma, certificate or badge. You can choose the other way for any category.
    public var usesPeriod: Bool?

    public var isPeriod: Bool { usesPeriod ?? category.hasPeriod }

    public init(category: VaultCategory, folderIDs: [String] = []) {
        self.category = category
        self.folderIDs = folderIDs
    }

    public init(item: VaultItem) {
        category = item.category
        title = item.title
        description = item.description ?? ""
        organisationName = item.organisationName ?? ""
        organisationLocation = item.organisationLocation ?? ""
        startDate = item.startDate
        endDate = item.endDate
        issuedOn = item.issuedOn
        isCurrent = item.isCurrent
        folderIDs = item.folderIDs
        if item.startDate != nil {
            usesPeriod = true
        } else if item.issuedOn != nil {
            usesPeriod = false
        }
    }

    /// The fields the "Bewijs toevoegen" form asks for (Figma marks them all as required).
    public enum Field: CaseIterable, Sendable {
        case title
        case organisation
        case period
        case description
    }

    /// The fields of the form that are still empty, in the order they appear.
    public var missingFields: [Field] {
        Field.allCases.filter { field in
            switch field {
            case .title: Self.trimmed(title).isEmpty
            case .organisation: Self.trimmed(organisationName).isEmpty
            case .period: isPeriod ? startDate == nil : issuedOn == nil
            case .description: Self.trimmed(description).isEmpty
            }
        }
    }

    /// "feb 2025 - nu" or "jun 2025", the same way an item shows it; nil while nothing is chosen.
    public var period: String? {
        VaultItem(
            id: "",
            category: category,
            title: "",
            startDate: isPeriod ? startDate : nil,
            endDate: isPeriod && !isCurrent ? endDate : nil,
            issuedOn: isPeriod ? nil : issuedOn,
            isCurrent: isPeriod && isCurrent
        ).period
    }

    public static let maximumTitleLength = 200
    public static let maximumDescriptionLength = 10_000

    /// The first thing that keeps the draft from being saved, checked the same way as the database does.
    public var problem: Problem? {
        let title = Self.trimmed(title)
        if title.isEmpty { return .missingTitle }
        if title.count > Self.maximumTitleLength { return .titleTooLong }
        if description.count > Self.maximumDescriptionLength { return .descriptionTooLong }
        if isPeriod, !isCurrent, let startDate, let endDate, endDate < startDate { return .endBeforeStart }
        return nil
    }

    /// The columns for `vault_items`. Empty text becomes null, and only the dates of the chosen kind (a period or one
    /// date) are kept.
    var row: [String: Any] {
        let hasPeriod = isPeriod
        return [
            "category": category.rawValue,
            "title": Self.trimmed(title),
            "description": Self.json(Self.trimmed(description)),
            "organisation_name": Self.json(Self.trimmed(organisationName)),
            "organisation_location": Self.json(Self.trimmed(organisationLocation)),
            "start_date": Self.json(hasPeriod ? startDate?.text : nil),
            "end_date": Self.json(hasPeriod && !isCurrent ? endDate?.text : nil),
            "issued_on": Self.json(hasPeriod ? nil : issuedOn?.text),
            "is_current": hasPeriod && isCurrent,
            "folder_id": Self.json(folderIDs.first),
        ]
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func json(_ text: String?) -> Any {
        guard let text, !text.isEmpty else { return NSNull() }
        return text
    }
}
