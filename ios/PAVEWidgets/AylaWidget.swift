import SwiftUI
import WidgetKit

/// Ayla on the Home Screen and the Lock Screen: one tap to talk with her or to start a new chat. It shows nothing
/// about you, because the widget is visible without unlocking the iPhone.
struct AylaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AylaWidget", provider: AylaWidgetProvider()) { _ in
            AylaWidgetView()
        }
        .configurationDisplayName("Ayla")
        .description("Praat met Ayla of begin een nieuw gesprek.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct AylaWidgetEntry: TimelineEntry {
    let date: Date
}

/// The widget never changes, so there is one entry for good.
struct AylaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AylaWidgetEntry { AylaWidgetEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (AylaWidgetEntry) -> Void) {
        completion(AylaWidgetEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AylaWidgetEntry>) -> Void) {
        completion(Timeline(entries: [AylaWidgetEntry(date: .now)], policy: .never))
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
