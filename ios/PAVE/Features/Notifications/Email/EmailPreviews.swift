import SwiftUI

#if DEBUG
/// A mailbox for previews: one conversation with a reply and a file.
private final class PreviewMailbox: EmailMailbox {
    let account = EmailAccount(provider: .icloud, address: "ravi@icloud.com")

    func recentMessages() async throws -> [EmailMessage] {
        let renee = EmailAddress(name: "Renée de Vries", address: "renee@fontys.nl")
        let me = EmailAddress(name: "Ravi", address: account.address)
        return [
            EmailMessage(
                id: "1", provider: .icloud, location: .imap(folder: "INBOX", uid: 1), messageID: "<a@x>", from: renee, to: [me],
                subject: "Stagegesprek", date: .now.addingTimeInterval(-7200), isRead: true, isFromMe: false,
                body: "Hoi Ravi, zullen we dinsdag om 10 uur je stage bespreken?"
            ),
            EmailMessage(
                id: "2", provider: .icloud, location: .imap(folder: "Sent Messages", uid: 2), messageID: "<b@x>", inReplyTo: "<a@x>",
                from: me, to: [renee], subject: "Re: Stagegesprek", date: .now.addingTimeInterval(-5400), isRead: true, isFromMe: true,
                body: "Dat is goed! Ik neem mijn stageplan mee."
            ),
            EmailMessage(
                id: "3", provider: .icloud, location: .imap(folder: "INBOX", uid: 3), messageID: "<c@x>", references: ["<a@x>", "<b@x>"],
                from: renee, to: [me], subject: "Re: Stagegesprek", date: .now.addingTimeInterval(-600), isRead: false, isFromMe: false,
                hasAttachments: true, body: "Top. Hierbij alvast het beoordelingsformulier.",
                attachments: [EmailAttachment(id: "0", name: "Beoordelingsformulier.pdf", mimeType: "application/pdf", size: 182_000, data: Data())]
            ),
        ]
    }

    func load(_ messages: [EmailMessage]) async throws -> [EmailMessage] { messages }
    func attachmentData(_ attachment: EmailAttachment, of message: EmailMessage) async throws -> Data { Data() }
    func markRead(_ messages: [EmailMessage]) async throws {}
    func send(to recipients: [EmailAddress], subject: String, text: String, attachments: [EmailOutgoingAttachment]) async throws -> EmailSent { EmailSent() }
    func reply(to message: EmailMessage, recipients: EmailReplyRecipients, text: String, attachments: [EmailOutgoingAttachment]) async throws -> EmailSent { EmailSent() }
    func disconnect() async {}
    func setSenderName(_ name: String?) {}
    func trash(_ messages: [EmailMessage]) async throws {}
    func restore(_ messages: [EmailTrashedMessage]) async throws {}
}

private struct EmailPreview<Content: View>: View {
    @State private var model = EmailModel(mailboxes: [PreviewMailbox()])
    @ViewBuilder let content: (EmailModel) -> Content

    var body: some View {
        NavigationStack { content(model) }
            .environment(model)
            .task { await model.refresh() }
    }
}

#Preview("E-mail · gesprek") {
    EmailPreview { model in
        if let id = model.threads.first?.id { EmailThreadScreen(threadID: id) }
    }
}

#Preview("E-mail · accounts") {
    EmailPreview { _ in EmailAccountsScreen() }
}

#Preview("Meldingen · met e-mail") {
    EmailPreview { model in
        NotificationsScreen(onShowMenu: {}, notifications: model.notifications)
    }
}
#endif
