import Foundation

/// What you did at the fair today, kept on this device for Mijn beursdag: the stands you scanned and where you left
/// your card. Older days drop off.
enum FairDay {
    enum Event: Codable, Equatable {
        case scanned(employer: String, slug: String, stand: String?)
        case applied(employer: String, vacancy: String)
    }

    struct Entry: Codable, Equatable, Identifiable {
        var id: Date { date }
        let date: Date
        let event: Event
    }

    private static let key = "fair.day"

    static func record(_ event: Event, at date: Date = .now) {
        var entries = all()
        // Scanning the same stand again today is not news.
        if case .scanned(_, let slug, _) = event, entries.contains(where: { if case .scanned(_, slug, _) = $0.event { return true } else { return false } }) { return }
        entries.append(Entry(date: date, event: event))
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// Today's entries, oldest first.
    static func all(now: Date = .now) -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key), let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
    }
}
