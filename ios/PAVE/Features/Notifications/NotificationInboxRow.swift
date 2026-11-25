import SwiftUI

/// One row of the Meldingen list. Flat, inside the section's panel: icon, title, who or what it is about, and on the
/// right when it happened. Unread is a bold title and a dot, not a tinted card.
struct NotificationInboxRow: View {
    let notification: PaveNotification
    var isUnread = false
    /// More than one when several meldingen of the same chat are folded into this row.
    var count = 1

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(notification.kind.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(notification.kind.tint)
                .frame(width: 18, height: 18)
                .frame(width: 36, height: 36)
                .background(notification.kind.surface, in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .textStyle(isUnread ? .listTitle : .bodyMedium)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(Self.when(notification.date))
                    .textStyle(.caption)
                    .foregroundStyle(isUnread ? Color.paveAccent : Color.inkMuted)
                if isUnread {
                    Circle().fill(Color.paveAccent).frame(width: 8, height: 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private var subtitle: String {
        notification.kind == .conversation && count > 1
            ? "\(notification.personName) · \(count) berichten"
            : notification.detail
    }

    /// The time today, "gisteren", the weekday this week, otherwise the date.
    static func when(_ date: Date) -> String {
        let calendar = Calendar.current
        let dutch = Locale(identifier: "nl_NL")
        if calendar.isDateInToday(date) { return date.formatted(.dateTime.hour().minute().locale(dutch)) }
        if calendar.isDateInYesterday(date) { return "gisteren" }
        if let week = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)), date >= week {
            return date.formatted(.dateTime.weekday(.abbreviated).locale(dutch))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(dutch))
    }
}

#Preview {
    List {
        Section("Actie nodig") {
            NotificationInboxRow(
                notification: .init(id: "1", kind: .verificationRequest, title: "Verificatie aanvraag", personName: "Fontys", date: .now, learnerName: "Ravi", documentName: "Hbo-ICT propedeuse"),
                isUnread: true
            )
            .listRowBackground(Color.panel)
        }
        Section("Deze week") {
            NotificationInboxRow(notification: .init(id: "2", kind: .conversation, title: "Cursus over design", personName: "Ayla", date: .now.addingTimeInterval(-90000)), isUnread: true, count: 3)
                .listRowBackground(Color.panel)
            NotificationInboxRow(notification: .init(id: "3", kind: .verifiedEvidence, title: "Bewijs geverifieerd", personName: "Fontys", date: .now.addingTimeInterval(-200000), documentName: "Diploma"))
                .listRowBackground(Color.panel)
        }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color.canvas)
}
