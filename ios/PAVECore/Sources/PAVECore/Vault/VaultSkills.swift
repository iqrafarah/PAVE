import Foundation

/// Skills as you add them to an item: trimmed, at most 120 characters, and each name once regardless of capitals.
public enum VaultSkills {
    public static let maximumLength = 120

    public static func cleaned(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.compactMap { name in
            let name = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !name.isEmpty, name.count <= maximumLength, seen.insert(name.lowercased()).inserted else { return nil }
            return name
        }
    }

    /// The skills already in your vault, the ones you used most first: what you can pick from for a new item.
    public static func known(in items: [VaultItem]) -> [String] {
        var counts: [String: (name: String, count: Int)] = [:]
        for name in items.flatMap(\.skills) {
            let key = name.lowercased()
            counts[key] = (counts[key]?.name ?? name, (counts[key]?.count ?? 0) + 1)
        }
        return counts.values
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map(\.name)
    }
}
