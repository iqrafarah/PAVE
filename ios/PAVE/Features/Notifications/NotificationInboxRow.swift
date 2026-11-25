import SwiftUI

/// One row of the Meldingen list. Flat, inside the section's panel: icon, title, who or what it is about, and on the
/// right when it happened. Unread is a bold title and a dot, not a tinted card.
struct NotificationInboxRow: View {
    let notification: PaveNotification
    var isUnread = false
    /// More than one when several meldingen of the same chat are folded into this row.
    var count = 1

    var body: some View {
        if notification.kind == .email {
            emailRow
        } else {
            meldingRow
        }
    }

    /// E-mail reads as in Messages: who, then the subject, then the start of the last message, and the time.
    private var emailRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // A fixed column, so one photo and a group's two line up the same.
            Group {
                if notification.emailPeople.isEmpty {
                    // Locked: no photo either, it would give away who it is.
                    Image(.iconLockClosedSolid)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.paveAccent)
                        .frame(width: 44, height: 44)
                        .background(Color.paveSurfaceTint, in: .circle)
                } else {
                    EmailAvatarStack(people: notification.emailPeople, size: 44)
                }
            }
                .frame(width: 58, alignment: .center)
                .overlay(alignment: .leading) {
                    if isUnread {
                        Circle().fill(Color.paveAccent).frame(width: 9, height: 9).offset(x: -10)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(notification.personName)
                        .textStyle(isUnread ? .listTitle : .bodyMedium)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    if notification.emailIsLocked {
                        Image(.iconLockClosedSolid)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 11, height: 11)
                            .foregroundStyle(Color.inkMuted)
                            .accessibilityLabel("Vergrendeld")
                    }
                    if notification.emailIsMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.inkMuted)
                            .accessibilityLabel("Gedempt")
                    }
                    Spacer(minLength: 4)
                    Text(Self.when(notification.date))
                        .textStyle(.caption)
                        .foregroundStyle(isUnread ? Color.paveAccent : Color.inkMuted)
                }
                if !notification.title.isEmpty {
                    Text(notification.title)
                        .textStyle(.caption)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                }
                if let preview = notification.emailPreview {
                    Text(preview)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(2)
                }
            }
        }
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private var meldingRow: some View {
        HStack(alignment: .top, spacing: 12) {
            if notification.kind == .email, !notification.emailPeople.isEmpty {
                // E-mail is from a person: their photo, as in a chat list.
                EmailAvatarStack(people: notification.emailPeople, size: 36)
            } else {
                Image(notification.kind.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(notification.kind.tint)
                    .frame(width: 18, height: 18)
                    .frame(width: 36, height: 36)
                    .background(notification.kind.surface, in: .rect(cornerRadius: 10))
            }

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
        if calendar.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if calendar.isDateInYesterday(date) { return "gisteren" }
        if let week = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)), date >= week {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
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
