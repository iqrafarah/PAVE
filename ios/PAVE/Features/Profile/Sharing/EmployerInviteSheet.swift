import PAVECore
import SwiftUI

/// The recruiter picks a moment for the talk and adds a short line; the applicant gets it in PAVE.
struct EmployerInviteSheet: View {
    let application: InboxApplication
    let onSend: (Date, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var moment = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now.addingTimeInterval(2 * 86_400)) ?? .now
    @State private var message = ""
    @State private var isSending = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section(SharingMessages.inviteWhen) {
                    DatePicker(SharingMessages.inviteWhen, selection: $moment, in: Date.now.addingTimeInterval(3600)...Date.now.addingTimeInterval(60 * 86_400), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, PaveLanguageStore.current.locale)
                }
                Section(SharingMessages.inviteMessage) {
                    TextField(SharingMessages.inviteMessage, text: $message, prompt: Text(SharingMessages.inviteMessagePrompt), axis: .vertical)
                        .lineLimit(2...4)
                }
                if failed {
                    Text(SharingMessages.inviteFailed).foregroundStyle(Color.critical)
                }
            }
            .navigationTitle(SharingMessages.inviteTitle(application.name ?? SharingMessages.you))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(SharingMessages.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(SharingMessages.inviteSend) {
                        isSending = true
                        Task {
                            let ok = await onSend(moment, message)
                            isSending = false
                            if ok { PaveHaptics.success(); dismiss() } else { failed = true }
                        }
                    }
                    .disabled(isSending)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
