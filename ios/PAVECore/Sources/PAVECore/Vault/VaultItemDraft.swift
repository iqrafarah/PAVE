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
    public var folderID: String?

    public init(category: VaultCategory, folderID: String? = nil) {
        self.category = category
        self.folderID = folderID
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
        folderID = item.folderID
    }

    public static let maximumTitleLength = 200
    public static let maximumDescriptionLength = 10_000

    /// The first thing that keeps the draft from being saved, checked the same way as the database does.
    public var problem: Problem? {
        let title = Self.trimmed(title)
        if title.isEmpty { return .missingTitle }
        if title.count > Self.maximumTitleLength { return .titleTooLong }
        if description.count > Self.maximumDescriptionLength { return .descriptionTooLong }
        if category.hasPeriod, !isCurrent, let startDate, let endDate, endDate < startDate { return .endBeforeStart }
        return nil
    }

    /// The columns for `vault_items`. Empty text becomes null, and only the dates that fit the category are kept.
    var row: [String: Any] {
        let hasPeriod = category.hasPeriod
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
            "folder_id": Self.json(folderID),
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
