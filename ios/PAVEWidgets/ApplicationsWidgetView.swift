import SwiftUI
import WidgetKit

/// The widget's face: the first application big on the small one, up to three in a list on the medium one.
struct ApplicationsWidgetView: View {
    let entry: ApplicationsWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.rows.isEmpty {
                empty
            } else if family == .systemSmall, let first = entry.rows.first {
                small(first)
            } else {
                list
            }
        }
        .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
        .widgetURL(URL(string: "pave://ayla/sollicitaties"))
    }

    private var title: some View {
        Text("Mijn sollicitaties")
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.accent)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
            Spacer(minLength: 0)
            Text("Nog geen sollicitaties")
                .font(.subheadline.weight(.semibold))
            Text("Solliciteer vanuit een vacature in PAVE.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func small(_ row: ApplicationsSnapshot.Row) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title
            Spacer(minLength: 0)
            if let days = row.deadlineDays {
                Text(Self.deadline(days))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(days <= 1 ? Color.red : entry.accent)
                    .privacySensitive()
            } else {
                Text(row.status)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(entry.accent)
            }
            Text(row.company)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .privacySensitive()
            if let looks = row.looks {
                Text(Self.looks(looks))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .privacySensitive()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            title
            ForEach(entry.rows.prefix(3), id: \.self) { row in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.company).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text([row.title, row.looks.map(Self.looks)].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .privacySensitive()
                    Spacer(minLength: 4)
                    Text(row.deadlineDays.map(Self.deadline) ?? row.status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle((row.deadlineDays ?? 9) <= 1 ? Color.red : entry.accent)
                        .privacySensitive()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    static func deadline(_ days: Int) -> String {
        switch days {
        case ..<0: "Verlopen"
        case 0: "Vandaag"
        case 1: "Morgen"
        default: "Over \(days) dagen"
        }
    }

    static func looks(_ count: Int) -> String {
        count == 0 ? "Gedeeld, nog niet bekeken" : count == 1 ? "1 keer bekeken" : "\(count) keer bekeken"
    }
}

#Preview(as: .systemSmall) {
    ApplicationsWidget()
} timeline: {
    ApplicationsWidgetEntry.example
}

#Preview(as: .systemMedium) {
    ApplicationsWidget()
} timeline: {
    ApplicationsWidgetEntry.example
}
