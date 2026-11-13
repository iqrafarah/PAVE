import Security
import SwiftUI
import WidgetKit

/// Ayla on the Home Screen and the Lock Screen: one tap to talk with her or to start a new chat. It shows nothing
/// about you, because the widget is visible without unlocking the iPhone.
struct AylaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AylaWidget", provider: AylaWidgetProvider()) { entry in
            AylaWidgetView(accent: entry.accent)
                .environment(\.paveAccentColor, entry.accent)
        }
        .configurationDisplayName("Ayla")
        .description("Praat met Ayla of begin een nieuw gesprek.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct AylaWidgetEntry: TimelineEntry {
    let date: Date
    var accent = Color.brandGreen

    /// The theme colour the app shares through the Keychain (PaveHomeScreen in the app); PAVE green until the app has
    /// shared one.
    static var current: AylaWidgetEntry {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "PaveKeychainGroup") as? String else { return AylaWidgetEntry(date: .now) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "nl.fontys.pave.theme",
            kSecAttrAccount as String: "widgetAccent",
            kSecAttrAccessGroup as String: group,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let hex = String(data: data, encoding: .utf8),
              hex.count == 7, let value = UInt32(hex.dropFirst(), radix: 16) else { return AylaWidgetEntry(date: .now) }
        let accent = Color(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
        return AylaWidgetEntry(date: .now, accent: accent)
    }
}

/// The widget only changes when the app chooses another theme colour and reloads it, so there is one entry for good.
struct AylaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AylaWidgetEntry { .current }

    func getSnapshot(in context: Context, completion: @escaping (AylaWidgetEntry) -> Void) {
        completion(.current)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AylaWidgetEntry>) -> Void) {
        completion(Timeline(entries: [.current], policy: .never))
    }
}

#Preview(as: .systemSmall) {
    AylaWidget()
} timeline: {
    AylaWidgetEntry(date: .now)
}

#Preview(as: .systemMedium) {
    AylaWidget()
} timeline: {
    AylaWidgetEntry(date: .now)
}

#Preview(as: .accessoryRectangular) {
    AylaWidget()
} timeline: {
    AylaWidgetEntry(date: .now)
}
