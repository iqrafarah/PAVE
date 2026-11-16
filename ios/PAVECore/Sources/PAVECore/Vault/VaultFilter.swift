import Foundation

/// Which part of the vault you look at: everything, one category or one of your own folders.
public enum VaultShelf: Hashable, Sendable {
    case all
    case category(VaultCategory)
    case folder(String)
}

/// The filters above the vault list: Status, Bron and Datum in the design, plus search.
public struct VaultFilter: Equatable, Sendable {
    public enum Origin: String, CaseIterable, Sendable {
        /// Added by you.
        case own
        /// From a school, employer or an import.
        case organisation
        case ayla

        func matches(_ source: VaultItem.Source) -> Bool {
            switch self {
            case .own: source == .user
            case .organisation: source == .organization || source == .import
            case .ayla: source == .ayla
            }
        }
    }

    public enum Order: String, CaseIterable, Sendable {
        case newest
        case oldest
    }

    public var shelf = VaultShelf.all
    public var status: VaultItem.Status?
    public var origin: Origin?
    public var order = Order.newest
    public var searchText = ""

    public init() {}

    /// Status or Bron is set. The shelf, the order and search do not count: "Alle" clears just these.
    public var narrowsDown: Bool {
        status != nil || origin != nil
    }

    public func apply(to items: [VaultItem], today: VaultDay = VaultDay(.now)) -> [VaultItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = items.filter { item in
            switch shelf {
            case .all: break
            case .category(let category): guard item.category == category else { return false }
            case .folder(let id): guard item.folderIDs.contains(id) else { return false }
            }
            if let status, item.status != status { return false }
            if let origin, !origin.matches(item.source) { return false }
            return query.isEmpty || Self.searchableText(of: item).localizedStandardContains(query)
        }
        return matching.sorted { lhs, rhs in
            let (left, right) = (lhs.sortDay(today: today), rhs.sortDay(today: today))
            if left == right { return lhs.updatedAt > rhs.updatedAt }
            return order == .newest ? left > right : left < right
        }
    }

    private static func searchableText(of item: VaultItem) -> String {
        ([item.title, item.category.title, item.organisationName, item.organisationLocation, item.description] + item.skills)
            .compactMap(\.self)
            .joined(separator: " ")
    }
}
