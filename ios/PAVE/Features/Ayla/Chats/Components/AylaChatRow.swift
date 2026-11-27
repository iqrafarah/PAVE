import PAVECore
import SwiftUI

/// One conversation in the list, as on the web: its name, a chat icon in front under Vastgezet, and "Op iPhone" under
/// it when it was begun on the iPhone.
struct AylaChatRow: View {
    let conversation: AylaConversation
    let isCurrent: Bool
    var showsIcon = false
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                if showsIcon {
                    Image(.iconChat)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(16)
                        .foregroundStyle(Color.paveAccent)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(conversation.title)
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    if conversation.startedOn == .phone {
                        Label {
                            Text(AylaMessages.startedOnPhone)
                        } icon: {
                            Image(.iconDevicePhoneMobile)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                        }
                        .labelStyle(.titleAndIcon)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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

    private static var locale: Locale { PaveLanguageStore.current.locale }

    /// The time today and yesterday (the group above already says which day), the day of the week this week,
    /// otherwise the date.
    static func when(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ...1:
            return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        case 2...6:
            return date.formatted(Date.FormatStyle().weekday(.wide).locale(locale)).capitalized(with: locale)
        default:
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            let style = sameYear
                ? Date.FormatStyle().day().month(.abbreviated)
                : Date.FormatStyle().day().month(.abbreviated).year()
            return date.formatted(style.locale(locale))
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
