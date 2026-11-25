import SwiftUI

/// "Recent verwijderd", as in Photos and Notes: deleted notifications, each restorable for 7 days.
/// Restore with a swipe, a long press, or the button on the row.
struct NotificationTrashScreen: View {
    let notifications: [PaveNotification]
    var onRestore: ((String) async -> Bool)?

    @Environment(EmailModel.self) private var email: EmailModel?
    @State private var failure: String?

    var body: some View {
        List {
            Text("Verwijderde meldingen blijven \(PaveNotification.restorableDays) dagen staan. Daarna zijn ze definitief weg.")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .notificationListRow(top: 16, bottom: 8)

            if notifications.isEmpty {
                PaveEmptyState(icon: .iconTrash, title: "Niets verwijderd", message: "Meldingen die je verwijdert, staan hier nog een week.")
                    .padding(.top, 30)
                    .frame(maxWidth: .infinity)
                    .notificationListRow()
            } else {
                ForEach(notifications) { notification in
                    row(notification)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .animation(.snappy, value: notifications.map(\.id))
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("Recent verwijderd")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Terugzetten lukte niet", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func row(_ notification: PaveNotification) -> some View {
        Button { restore(notification) } label: {
            NotificationRow(notification: notification, hint: daysLeft(notification), showsArrow: false)
        }
        .buttonStyle(.pave)
        .notificationListRow(top: 4, bottom: 4)
        .swipeActions(edge: .leading, allowsFullSwipe: true) { restoreButton(notification) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { restoreButton(notification) }
        .contextMenu { restoreButton(notification) }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tik om terug te zetten")
        .accessibilityActions { restoreButton(notification) }
    }

    private func restoreButton(_ notification: PaveNotification) -> some View {
        Button { restore(notification) } label: {
            Label("Terugzetten", tinted: .iconArrowPath)
        }
        .tint(.paveAccent)
    }

    private func restore(_ notification: PaveNotification) {
        Task {
            if await onRestore?(notification.id) == true {
                PaveHaptics.success()
            } else {
                PaveHaptics.error()
                failure = notification.kind == .email
                    ? email?.restoreProblem ?? "Het gesprek kon niet worden teruggezet. Probeer het opnieuw."
                    : "De melding kon niet worden teruggezet. Probeer het opnieuw."
            }
        }
    }

    private func daysLeft(_ notification: PaveNotification) -> String {
        guard let deadline = notification.restoreDeadline else { return "" }
        let days = max(1, Int((deadline.timeIntervalSinceNow / 86_400).rounded(.up)))
        return days == 1 ? "Nog 1 dag" : "Nog \(days) dagen"
    }
}

#Preview {
    NavigationStack {
        NotificationTrashScreen(notifications: [
            .init(id: "1", kind: .verifiedEvidence, title: "Bewijs geverifieerd", personName: "Fontys Hogeschool", date: .now.addingTimeInterval(-86_400), deletedAt: .now.addingTimeInterval(-3600), documentName: "Hbo-ICT propedeuse"),
            .init(id: "2", kind: .conversation, title: "Gesprek voor stage", personName: "Ayla", date: .now.addingTimeInterval(-400_000), deletedAt: .now.addingTimeInterval(-6 * 86_400)),
        ])
    }
}
