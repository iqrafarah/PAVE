import PAVECore
import SwiftUI

/// One conversation in the list: its name, and underneath when it was last used and, when it began elsewhere, where.
struct AylaChatRow: View {
    let conversation: AylaConversation
    let isCurrent: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(Self.when(conversation.updatedAt))
                    if let place = Self.place(conversation.startedOn) {
                        Image(systemName: place.symbol)
                            .imageScale(.small)
                            .accessibilityHidden(true)
                        Text(place.label)
                    }
                }
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, 12)
            .background {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 12).fill(Color.paveSurfaceTint)
                }
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .hoverEffect(.highlight)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    private static let dutch = Locale(identifier: "nl_NL")

    /// The time today and yesterday (the group above already says which day), the day of the week this week,
    /// otherwise the date.
    static func when(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ...1:
            return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(dutch))
        case 2...6:
            return date.formatted(Date.FormatStyle().weekday(.wide).locale(dutch)).capitalized(with: dutch)
        default:
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            let style = sameYear
                ? Date.FormatStyle().day().month(.abbreviated)
                : Date.FormatStyle().day().month(.abbreviated).year()
            return date.formatted(style.locale(dutch))
        }
    }

    /// Only conversations that began somewhere else than on this phone say so.
    static func place(_ device: AylaDevice?) -> (symbol: String, label: String)? {
        switch device {
        case .web: ("globe.europe.africa.fill", "Op web")
        case .watch: WatchConnectMessages.isShown ? ("applewatch", "Op Apple Watch") : nil
        case .phone, nil: nil
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        AylaChatRow(conversation: AylaConversation(id: "1", title: "Softskills uitwerken", updatedAt: .now), isCurrent: true) {}
        AylaChatRow(
            conversation: AylaConversation(id: "2", title: "Ik wil graag docent ICT worden bij een hogeschool in Brabant", updatedAt: .now.addingTimeInterval(-86_400 * 3), startedOn: .web),
            isCurrent: false
        ) {}
    }
    .padding()
}
