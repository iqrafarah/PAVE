import Security
import SwiftUI
import WidgetKit

/// "Mijn sollicitaties" on the Home Screen: the open applications, how close their deadline is, and how often what you
/// shared was looked at. Company names and numbers are marked private, so a locked iPhone hides them.
struct ApplicationsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ApplicationsWidget", provider: ApplicationsWidgetProvider()) { entry in
            ApplicationsWidgetView(entry: entry)
                .environment(\.paveAccentColor, entry.accent)
        }
        .configurationDisplayName("Mijn sollicitaties")
        .description("Je deadlines en wie keek naar wat je deelde.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// The same keys as ApplicationWidgetSnapshot in the app, which writes them.
struct ApplicationsSnapshot: Codable {
    struct Row: Codable, Hashable {
        var company: String
        var title: String
        var status: String
        var deadlineDays: Int?
        var looks: Int?
    }
    var rows: [Row]
    var updatedAt: Date
}

struct ApplicationsWidgetEntry: TimelineEntry {
    let date: Date
    var rows: [ApplicationsSnapshot.Row] = []
    var accent = AylaWidgetEntry.current.accent

    static var current: ApplicationsWidgetEntry {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "PaveKeychainGroup") as? String else { return ApplicationsWidgetEntry(date: .now) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "nl.fontys.pave.applications",
            kSecAttrAccount as String: "snapshot",
            kSecAttrAccessGroup as String: group,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data,
              let snapshot = try? JSONDecoder().decode(ApplicationsSnapshot.self, from: data) else { return ApplicationsWidgetEntry(date: .now) }
        // Days to a deadline count from when the app wrote them; the widget moves them on with the calendar.
        let passed = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: snapshot.updatedAt), to: Calendar.current.startOfDay(for: .now)).day ?? 0
        let rows = snapshot.rows.map { row in
            var row = row
            row.deadlineDays = row.deadlineDays.map { $0 - passed }
            return row
        }
        return ApplicationsWidgetEntry(date: .now, rows: rows)
    }

    static let example = ApplicationsWidgetEntry(date: .now, rows: [
        .init(company: "Kade Consultancy", title: "Junior IT-consultant", status: "Concept", deadlineDays: 3, looks: 2),
        .init(company: "Studio Noorderlicht", title: "Junior iOS-ontwikkelaar", status: "Verstuurd", deadlineDays: nil, looks: nil),
    ])
}

/// Read again at midnight, so "over 3 dagen" becomes "over 2 dagen"; the app reloads it when something changes.
struct ApplicationsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ApplicationsWidgetEntry { .example }

    func getSnapshot(in context: Context, completion: @escaping (ApplicationsWidgetEntry) -> Void) {
        completion(context.isPreview ? .example : .current)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ApplicationsWidgetEntry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [.current], policy: .after(midnight)))
    }
}
