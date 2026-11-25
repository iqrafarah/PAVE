import Foundation
import Testing
@testable import PAVE

@MainActor
struct EmailTests {
    // MARK: MIME

    @Test func readsHeadersTextAndAttachmentsOfAMultipartMessage() {
        let raw = """
        From: =?utf-8?Q?Ren=C3=A9e?= de Vries <renee@fontys.nl>
        To: Ravi <ravi@icloud.com>, "Noor, El" <noor@x.nl>
        Subject: =?utf-8?B?U3RhZ2Ugw6lu?= gesprek
        Date: Tue, 24 Nov 2026 09:12:03 +0100 (CET)
        Message-ID: <abc@fontys.nl>
        In-Reply-To: <root@icloud.com>
        References: <root@icloud.com>
         <second@fontys.nl>
        Content-Type: multipart/mixed; boundary="XYZ"

        --XYZ
        Content-Type: text/plain; charset=utf-8
        Content-Transfer-Encoding: quoted-printable

        Hoi Ravi, caf=C3=A9 om 10=
         uur?
        --XYZ
        Content-Type: application/pdf; name="cv.pdf"
        Content-Disposition: attachment; filename*=utf-8''CV%20Ren%C3%A9e.pdf
        Content-Transfer-Encoding: base64

        SGFsbG8=
        --XYZ--
        """.replacingOccurrences(of: "\n", with: "\r\n")
        let mime = MIMEMessage(data: Data(raw.utf8))

        #expect(mime.from == EmailAddress(name: "Renée de Vries", address: "renee@fontys.nl"))
        #expect(mime.to.map(\.address) == ["ravi@icloud.com", "noor@x.nl"])
        #expect(mime.to.last?.name == "Noor, El")
        #expect(mime.subject == "Stage én gesprek")
        #expect(mime.messageID == "<abc@fontys.nl>")
        #expect(mime.references == ["<root@icloud.com>", "<second@fontys.nl>"])
        #expect(mime.date == Date(timeIntervalSince1970: 1_795_507_923))
        #expect(mime.bodyText == "Hoi Ravi, café om 10 uur?")
        #expect(mime.attachments.count == 1)
        #expect(mime.attachments.first?.name == "CV Renée.pdf")
        #expect(mime.attachments.first?.data == Data("Hallo".utf8))
    }

    @Test func fallsBackToHTMLWhenThereIsNoPlainText() {
        let raw = "Content-Type: text/html; charset=utf-8\r\n\r\n<p>Hallo&nbsp;daar</p><br><b>Groet</b>"
        #expect(MIMEMessage(data: Data(raw.utf8)).bodyText == "Hallo daar\n\nGroet")
    }

    @Test func aLogoInsideTheHTMLIsNoAttachment() {
        let raw = """
        Content-Type: multipart/related; boundary=R

        --R
        Content-Type: text/html

        <p>Hoi</p>
        --R
        Content-Type: image/png; name=logo.png
        Content-ID: <logo>
        Content-Transfer-Encoding: base64

        iVBORw0K
        --R--
        """
        let mime = MIMEMessage(data: Data(raw.utf8))
        #expect(mime.attachments.isEmpty)
        #expect(mime.bodyText == "Hoi")
    }

    @Test func aReplyCarriesTheThreadHeadersAndItsFiles() {
        let original = message(id: "1", from: "renee@fontys.nl", subject: "Stage", messageID: "<a@fontys.nl>", references: ["<root@x>"])
        let file = EmailOutgoingAttachment(name: "cv.pdf", mimeType: "application/pdf", data: Data("PDF".utf8))
        let (data, id) = MIMEBuilder.reply(
            from: EmailAddress(name: "Ravi", address: "ravi@icloud.com"),
            to: [original.from], cc: [], subject: "Re: Stage", text: "Prima!",
            quoting: original, attachments: [file]
        )
        let parsed = MIMEMessage(data: data)
        #expect(parsed.inReplyTo == "<a@fontys.nl>")
        #expect(parsed.references == ["<root@x>", "<a@fontys.nl>"])
        #expect(parsed.messageID == id)
        #expect(EmailThreading.stripQuotedText(parsed.bodyText) == "Prima!")
        #expect(parsed.attachments.first?.name == "cv.pdf")
        #expect(parsed.attachments.first?.data == Data("PDF".utf8))
    }

    // MARK: Threads

    @Test func groupsByReferencesAndKeepsOtherConversationsApart() {
        let first = message(id: "1", from: "renee@fontys.nl", subject: "Stage", messageID: "<a@x>", date: 1)
        let reply = message(id: "2", from: "ravi@icloud.com", subject: "Re: Stage", messageID: "<b@x>", inReplyTo: "<a@x>", date: 2, isFromMe: true, to: ["renee@fontys.nl"])
        let again = message(id: "3", from: "renee@fontys.nl", subject: "RE: Re: Stage", messageID: "<c@x>", references: ["<a@x>", "<b@x>"], date: 3)
        let other = message(id: "4", from: "school@x.nl", subject: "Rooster", messageID: "<d@x>", date: 4)

        let threads = EmailThreading.threads(from: [other, again, first, reply])
        #expect(threads.count == 2)
        #expect(threads.first?.messages.map(\.id) == ["4"])
        let stage = threads.first { $0.subject == "Stage" }
        #expect(stage?.messages.map(\.id) == ["1", "2", "3"])
        #expect(stage?.unreadCount == 2)
        #expect(stage?.participants.map(\.address) == ["renee@fontys.nl"])
    }

    @Test func messagesWithoutHeadersJoinBySubjectAndPerson() {
        let a = message(id: "1", from: "x@y.nl", subject: "Vraag", date: 1)
        let b = message(id: "2", from: "x@y.nl", subject: "Re: Vraag", date: 2)
        let c = message(id: "3", from: "z@y.nl", subject: "Vraag", date: 3)
        #expect(EmailThreading.threads(from: [a, b, c]).count == 2)
    }

    @Test func subjectsLoseTheirReplyPrefixes() {
        #expect(EmailThreading.normalizedSubject("Re: RE: Fwd: Stage") == "Stage")
        #expect(EmailThreading.normalizedSubject("Antw: [EXTERN] Stage") == "Stage")
        #expect(EmailThreading.normalizedSubject("Re[2]: Stage") == "Stage")
        #expect(EmailThreading.normalizedSubject("Agenda: dinsdag") == "Agenda: dinsdag")
    }

    // MARK: Quotes

    @Test func cutsTheQuotedHistory() {
        #expect(EmailThreading.stripQuotedText("Top!\n\nOp 24 nov. 2026 om 09:12 schreef Renée <r@x.nl>:\n> Hoi") == "Top!")
        #expect(EmailThreading.stripQuotedText("Sure\n\nOn Tue, Nov 24, 2026 at 9:12 AM Renée <r@x.nl>\nwrote:\n> Hi") == "Sure")
        #expect(EmailThreading.stripQuotedText("Goed\n\nVan: Renée\nVerzonden: dinsdag\nAan: Ravi") == "Goed")
        #expect(EmailThreading.stripQuotedText("Ok\n-----Original Message-----\nFrom: x") == "Ok")
    }

    @Test func keepsInlineAnswersBetweenQuotes() {
        let text = "> Kun je dinsdag?\nJa, om 10 uur.\n> En woensdag?\nNee."
        #expect(EmailThreading.stripQuotedText(text) == text)
    }

    // MARK: IMAP

    @Test func readsAFetchResponseWithALiteral() {
        let response = IMAPResponse(segments: [
            .text(Data(#"* 12 FETCH (UID 40 FLAGS (\Seen \Answered) INTERNALDATE "24-Nov-2026 09:12:03 +0100" BODY[HEADER.FIELDS (FROM SUBJECT)] "#.utf8)),
            .literal(Data("Subject: Hoi\r\n\r\n".utf8)),
            .text(Data(")".utf8)),
        ])
        let items = IMAPParser.fetchItems(response.values)
        #expect(items?["UID"]?.text == "40")
        #expect(items?["FLAGS"]?.items.compactMap(\.text) == ["\\Seen", "\\Answered"])
        #expect(items?["INTERNALDATE"]?.text == "24-Nov-2026 09:12:03 +0100")
        #expect(items?["BODY"]?.data == Data("Subject: Hoi\r\n\r\n".utf8))
    }

    @Test func readsAListResponse() {
        let values = IMAPResponse(segments: [.text(Data(#"* LIST (\HasNoChildren \Sent) "/" "Sent Messages""#.utf8))]).values
        #expect(values[1].text == "LIST")
        #expect(values[2].items.compactMap(\.text) == ["\\HasNoChildren", "\\Sent"])
        #expect(values[4].text == "Sent Messages")
    }

    // MARK: Replying

    @Test func aReplyGoesToEveryoneButYou() {
        var incoming = message(id: "1", from: "renee@fontys.nl", subject: "Stage", to: ["ravi@icloud.com", "noor@x.nl"])
        incoming.cc = [EmailAddress(name: nil, address: "Ravi@iCloud.com"), EmailAddress(name: nil, address: "docent@x.nl")]
        let recipients = EmailReplyRecipients(replyingTo: incoming, as: "ravi@icloud.com")
        #expect(recipients.to.map(\.address) == ["renee@fontys.nl", "noor@x.nl"])
        #expect(recipients.cc.map(\.address) == ["docent@x.nl"])

        let mine = message(id: "2", from: "ravi@icloud.com", subject: "Stage", isFromMe: true, to: ["renee@fontys.nl"])
        #expect(EmailReplyRecipients(replyingTo: mine, as: "ravi@icloud.com").to.map(\.address) == ["renee@fontys.nl"])
        #expect(EmailReplyRecipients.replySubject("RE: Stage") == "Re: Stage")
    }

    @Test func onlyApplesOwnAddressesCanUseICloudMail() {
        #expect(EmailICloudSheet.addressProblem("ravi@icloud.com") == nil)
        #expect(EmailICloudSheet.addressProblem("Ravi@Me.com") == nil)
        #expect(EmailICloudSheet.addressProblem("ravi@hotmail.com")?.contains("Hotmail") == true)
        #expect(EmailICloudSheet.addressProblem("ravi@gmail.com") != nil)
    }

    @Test func onlyConversationsWithPeopleYouKnowShowUp() {
        let friend = message(id: "1", from: "renee@fontys.nl", subject: "Stage")
        let stranger = message(id: "2", from: "iemand@x.nl", subject: "Hoi")
        var newsletter = message(id: "3", from: "renee@fontys.nl", subject: "Nieuws")
        newsletter.isAutomated = true
        let mine = message(id: "4", from: "ravi@icloud.com", subject: "Vraag", isFromMe: true, to: ["school@x.nl"])
        let known = EmailThreading.knownAddresses(in: [mine]).union(["renee@fontys.nl"])

        func shows(_ item: EmailMessage) -> Bool {
            EmailThreading.isConversation(EmailThread(id: item.id, provider: .icloud, messages: [item]), known: known)
        }
        #expect(shows(friend))
        #expect(!shows(stranger))
        #expect(!shows(newsletter))
        #expect(shows(mine))
        #expect(known.contains("school@x.nl"))
    }

    @Test func recognisesNewslettersAndNoReply() {
        #expect(MIMEMessage(data: Data("From: Winkel <info@winkel.nl>\r\nList-Unsubscribe: <mailto:x@y>\r\n\r\n".utf8)).isAutomated)
        #expect(MIMEMessage(data: Data("From: no-reply@apple.com\r\n\r\n".utf8)).isAutomated)
        #expect(MIMEMessage(data: Data("From: x@y.nl\r\nAuto-Submitted: auto-replied\r\n\r\n".utf8)).isAutomated)
        #expect(!MIMEMessage(data: Data("From: Renée <renee@fontys.nl>\r\n\r\n".utf8)).isAutomated)
    }

    @Test func bubblesGroupLikeMessages() {
        let a = message(id: "1", from: "renee@fontys.nl", subject: "S", date: 0)
        let b = message(id: "2", from: "renee@fontys.nl", subject: "S", date: 60)
        let c = message(id: "3", from: "ravi@icloud.com", subject: "S", date: 120, isFromMe: true)
        let d = message(id: "4", from: "ravi@icloud.com", subject: "S", date: 120 + 20 * 60, isFromMe: true)
        let layout = EmailBubbleLayout.make([a, b, c, d])
        #expect(layout.map(\.showsTime) == [true, false, false, true])
        #expect(layout.map(\.isFirstOfRun) == [true, false, true, true])
        #expect(layout.map(\.isLastOfRun) == [false, true, true, true])
    }

    @Test func textIsSentAsReadableQuotedPrintable() {
        let text = "Hoi Renée,\n\nZullen we om 10 uur afspreken? " + String(repeating: "lang ", count: 30)
        let encoded = MIMEBuilder.quotedPrintable(text)
        #expect(encoded.contains("Hoi Ren=C3=A9e,"))
        #expect(encoded.components(separatedBy: "\r\n").allSatisfy { $0.count <= 76 })
        let decoded = String(decoding: MIMEMessage.decodeQuotedPrintable(Data(encoded.utf8)), as: UTF8.self)
        #expect(decoded.replacingOccurrences(of: "\r\n", with: "\n") == text)
    }

    @Test func pendingMessagesKeepTheirOrder() async {
        let model = EmailModel(mailboxes: [FakeMailbox()])
        await model.refresh()
        let id = model.visibleThreads[0].id
        try? await model.reply(in: id, text: "Eén", attachments: [])
        try? await model.reply(in: id, text: "Twee", attachments: [])
        await model.refresh()
        let bodies = model.thread(id)?.messages.suffix(2).map(\.body)
        #expect(bodies == ["Eén", "Twee"])
    }

    @Test func theOutboxSurvivesARestart() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let outbox = EmailOutbox(url: folder.appending(path: "outbox.json"))
        let sent = EmailMessage(
            id: "local:x", provider: .icloud, location: .imap(folder: "", uid: 0), messageID: "<x@icloud.com>",
            from: EmailAddress(name: "Iqra", address: "iqra@icloud.com"), to: [EmailAddress(name: nil, address: "docent@x.nl")],
            subject: "Vraag", date: .now, isRead: true, isFromMe: true, body: "Hoi!",
            attachments: [EmailAttachment(id: "0", name: "cv.pdf", mimeType: "application/pdf", size: 10, data: Data("PDF".utf8))]
        )
        outbox.save([EmailOutbox.Entry(threadID: "icloud:x@icloud.com", message: sent)])
        let restored = try #require(outbox.load().first)
        #expect(restored.message.body == "Hoi!")
        #expect(restored.message.messageID == "<x@icloud.com>")
        #expect(restored.message.attachments.first?.name == "cv.pdf")
        #expect(restored.message.attachments.first?.data == nil)
        outbox.save([])
        #expect(outbox.load().isEmpty)
    }

    @Test func youAreNeverYourOwnConversationPartner() {
        // Mailing your own Gmail from iCloud: the other side is Gmail, never your iCloud address twice.
        let sent = message(id: "1", from: "iqra@icloud.com", subject: "Test", date: 1, isFromMe: true, to: ["iqra@gmail.com", "iqra@icloud.com"])
        let back = message(id: "2", from: "iqra@gmail.com", subject: "Re: Test", date: 2, to: ["iqra@icloud.com"])
        let thread = EmailThread(id: "t", provider: .icloud, messages: [sent, back])
        #expect(thread.participants.map(\.address) == ["iqra@gmail.com"])
    }

    @Test func anAnswerFromGmailJoinsTheConversationYouStarted() async {
        let mailbox = FakeMailbox()
        let model = EmailModel(mailboxes: [mailbox])
        await model.refresh()
        let started = try? await model.startConversation(
            to: [EmailAddress(name: nil, address: "docent@x.nl")], subject: "PAVE testing", text: "Test test", attachments: []
        )
        // Verzonden never got a copy, but the answer points at it.
        mailbox.extra = [EmailMessage(
            id: "g", provider: .icloud, location: .imap(folder: "INBOX", uid: 7), messageID: "<g@gmail.com>",
            inReplyTo: "<new@icloud.com>", references: ["<new@icloud.com>"],
            from: EmailAddress(name: "Docent", address: "docent@x.nl"), to: [EmailAddress(name: nil, address: "ravi@icloud.com")],
            subject: "Re: PAVE testing", date: .now, isRead: false, isFromMe: false
        )]
        await model.refresh()
        let thread = model.thread(started ?? "")
        #expect(thread?.messages.map(\.body) == ["Test test", "Hoi Ravi"])
        #expect(model.visibleThreads.filter { $0.subject == "PAVE testing" }.count == 1)
    }

    @Test func pinnedConversationsLeaveTheList() async {
        UserDefaults.standard.removeObject(forKey: EmailModel.pinnedKey)
        defer { UserDefaults.standard.removeObject(forKey: EmailModel.pinnedKey) }
        let model = EmailModel(mailboxes: [FakeMailbox()])
        await model.refresh()
        let id = model.visibleThreads[0].id
        model.togglePin(id)
        #expect(model.pinnedThreads.map(\.id) == [id])
        #expect(model.notifications.isEmpty)
        #expect(model.unreadCount == 1)
        model.togglePin(id)
        #expect(model.pinnedThreads.isEmpty)
        #expect(model.notifications.count == 1)
    }

    @Test func deletingAConversationCanBeUndone() async {
        let mailbox = FakeMailbox()
        let model = EmailModel(mailboxes: [mailbox])
        await model.refresh()
        let id = model.visibleThreads[0].id

        model.delete(id)
        #expect(model.visibleThreads.isEmpty)
        model.undoDelete(id)
        #expect(model.visibleThreads.count == 1)
        try? await Task.sleep(for: .seconds(EmailModel.undoSeconds + 0.5))
        #expect(mailbox.trashed.isEmpty)

        model.delete(id)
        try? await Task.sleep(for: .seconds(EmailModel.undoSeconds + 0.5))
        #expect(Set(mailbox.trashed) == ["0", "1"])
        #expect(model.thread(id) == nil)
    }

    @Test func deletingOneMessageKeepsTheRest() async {
        let mailbox = FakeMailbox()
        let model = EmailModel(mailboxes: [mailbox])
        await model.refresh()
        let thread = model.visibleThreads[0]
        await model.delete(thread.messages[0], in: thread.id)
        #expect(mailbox.trashed == [thread.messages[0].id])
        #expect(model.thread(thread.id)?.messages.count == thread.messages.count - 1)
    }

    @Test func aDeletedConversationCanBeRestored() async {
        let mailbox = FakeMailbox()
        let model = EmailModel(mailboxes: [mailbox])
        await model.refresh()
        let id = model.visibleThreads[0].id
        model.delete(id)
        try? await Task.sleep(for: .seconds(EmailModel.undoSeconds + 0.5))
        #expect(model.deletedNotifications.map(\.emailThreadID) == [id])
        #expect(model.deletedNotifications.first?.deletedAt != nil)

        #expect(await model.restore(id))
        #expect(Set(mailbox.restored.map(\.messageID)) == ["<z@x>", "<a@x>"])
        #expect(model.deletedNotifications.isEmpty)
    }

    @Test func theRowShowsTheLastMessage() {
        var mine = message(id: "1", from: "ravi@icloud.com", subject: "Stage", date: 1, isFromMe: true, to: ["renee@fontys.nl"])
        mine.body = "Tot dinsdag!\nGroet"
        #expect(EmailModel.preview(of: EmailThread(id: "t", provider: .icloud, messages: [mine])) == "Jij: Tot dinsdag! Groet")
        var file = message(id: "2", from: "renee@fontys.nl", subject: "Stage", date: 2)
        file.body = ""
        file.attachments = [EmailAttachment(id: "0", name: "a.pdf", mimeType: "application/pdf", size: 1)]
        #expect(EmailModel.preview(of: EmailThread(id: "t", provider: .icloud, messages: [file])) == "Bijlage")
    }

    @Test func markingAllReadIsOneVisit() async {
        let mailbox = FakeMailbox()
        let model = EmailModel(mailboxes: [mailbox])
        await model.refresh()
        await model.markAllRead()
        #expect(model.unreadCount == 0)
        #expect(mailbox.markedRead == ["1"])
    }

    @Test func aConversationOnlyOnThisIPhoneAlsoGoesToRecentlyDeleted() async {
        let mailbox = FakeMailbox()
        let model = EmailModel(mailboxes: [mailbox])
        await model.refresh()
        let started = try? await model.startConversation(
            to: [EmailAddress(name: nil, address: "docent@x.nl")], subject: "Alleen hier", text: "Hoi", attachments: []
        )
        let id = started ?? ""
        model.delete(id)
        try? await Task.sleep(for: .seconds(EmailModel.undoSeconds + 0.5))
        #expect(mailbox.trashed.isEmpty)
        #expect(model.deletedNotifications.map(\.title) == ["Alleen hier"])

        #expect(await model.restore(id))
        #expect(model.thread(id)?.messages.first?.body == "Hoi")
    }

    @Test func searchFindsWhatIsInsideAMessage() async {
        let model = EmailModel(mailboxes: [FakeMailbox()])
        await model.refresh()
        #expect(model.threadIDs(matching: "hoi ravi") == [model.visibleThreads[0].id])
        #expect(model.threadIDs(matching: "renee@fontys").count == 1)
        #expect(model.threadIDs(matching: "aanbieding").isEmpty)
    }

    @Test func smtpDoublesLeadingDots() {
        let data = SMTPClient.dotStuffed(Data("Hoi\n.verborgen\nklaar".utf8))
        #expect(String(decoding: data, as: UTF8.self) == "Hoi\r\n..verborgen\r\nklaar\r\n")
    }

    // MARK: Model

    @Test func conversationsBecomeMeldingenAndOpenWithTheirText() async {
        let mailbox = FakeMailbox()
        let model = EmailModel(mailboxes: [mailbox])
        await model.refresh()

        #expect(model.threads.count == 2)
        #expect(model.visibleThreads.count == 1)
        #expect(model.unreadCount == 1)
        let row = model.notifications.first
        #expect(row?.kind == .email)
        #expect(row?.title == "Stage")
        #expect(row?.personName == "Renée")
        #expect(EmailModel.threadID(fromNotification: row?.id ?? "") == model.visibleThreads.first?.id)

        let id = model.visibleThreads[0].id
        await model.open(id)
        #expect(model.thread(id)?.messages.last?.body == "Hoi Ravi")
        #expect(model.unreadCount == 0)
        #expect(mailbox.markedRead == ["1"])

        try? await model.reply(in: id, text: "Top", attachments: [])
        #expect(mailbox.replies == ["Top"])
        #expect(model.thread(id)?.messages.last?.isFromMe == true)
        // The reply stays until Verzonden has its copy, even though this refresh does not bring it.
        await model.refresh()
        #expect(model.thread(id)?.messages.last?.body == "Top")

        let started = try? await model.startConversation(
            to: [EmailAddress(name: nil, address: "docent@x.nl")], subject: "Vraag", text: "Hoi!", attachments: []
        )
        #expect(started == "icloud:new@icloud.com")
        #expect(model.visibleThreads.first?.id == started)
        // Not in Verzonden yet, but a refresh keeps it.
        await model.refresh()
        #expect(model.thread(started ?? "")?.messages.first?.body == "Hoi!")

        await model.disconnect(.icloud)
        #expect(model.threads.isEmpty)
        #expect(!model.hasAccounts)
    }

    // MARK: Replying to one, forwarding

    @Test func antwoordGoesOnlyToTheSender() {
        var incoming = message(id: "1", from: "renee@fontys.nl", subject: "Stage", to: ["ravi@icloud.com", "noor@x.nl"])
        incoming.cc = [EmailAddress(name: nil, address: "docent@x.nl")]
        let one = EmailReplyRecipients(onlySenderOf: incoming, as: "ravi@icloud.com")
        #expect(one.to.map(\.address) == ["renee@fontys.nl"])
        #expect(one.cc.isEmpty)
        #expect(EmailReplyRecipients(replyingTo: incoming, as: "ravi@icloud.com").everyone.count == 3)

        let mine = message(id: "2", from: "ravi@icloud.com", subject: "Stage", isFromMe: true, to: ["ravi@icloud.com", "renee@fontys.nl"])
        #expect(EmailReplyRecipients(onlySenderOf: mine, as: "ravi@icloud.com").to.map(\.address) == ["renee@fontys.nl"])
    }

    @Test func aReplyToOnePersonReachesTheMailboxThatWay() async throws {
        let mailbox = FakeMailbox()
        mailbox.extraRecipients = ["docent@fontys.nl"]
        let model = EmailModel(mailboxes: [mailbox])
        await model.refresh()
        let id = try #require(model.visibleThreads.first?.id)
        try await model.reply(in: id, text: "Alleen jij", attachments: [], onlySender: true)
        try await model.reply(in: id, text: "Iedereen", attachments: [])
        #expect(mailbox.recipients == [["renee@fontys.nl"], ["renee@fontys.nl", "docent@fontys.nl"]])
    }

    @Test func forwardingKeepsTheOriginalUnderYourNote() {
        var original = message(id: "1", from: "renee@fontys.nl", subject: "Re: Certificaat", to: ["ravi@icloud.com"])
        original.body = "Hierbij je certificaat."
        let body = EmailForward.body(note: "Zie hieronder ", original: original)
        #expect(body.hasPrefix("Zie hieronder\n\n---------- Doorgestuurd bericht ----------"))
        #expect(body.contains("Van: renee@fontys.nl"))
        #expect(body.contains("Onderwerp: Re: Certificaat"))
        #expect(body.hasSuffix("Hierbij je certificaat."))
        #expect(EmailForward.body(note: "  ", original: original).hasPrefix("----------"))
        #expect(EmailForward.subject("Re: Certificaat") == "Fwd: Certificaat")
    }

    @Test func forwardingAConversationSendsEveryAnswerOldestFirst() {
        var question = message(id: "1", from: "ravi@icloud.com", subject: "Stage", date: 10, isFromMe: true, to: ["renee@fontys.nl"])
        question.body = "Kan ik stage lopen?"
        var answer = message(id: "2", from: "renee@fontys.nl", subject: "Re: Stage", date: 20)
        answer.body = "Ja, vanaf maart."
        let body = EmailForward.body(note: "", messages: [answer, question])
        #expect(body.components(separatedBy: "---------- Doorgestuurd bericht ----------").count == 3)
        let asked = body.range(of: "Kan ik stage lopen?")?.lowerBound
        let answered = body.range(of: "Ja, vanaf maart.")?.lowerBound
        #expect(asked != nil && answered != nil && asked! < answered!)
        #expect(EmailForwarding(messages: [answer, question]).subject == "Stage")
    }

    @Test func aForwardIsAConversationOfItsOwn() {
        let original = message(id: "1", from: "ravi@icloud.com", subject: "PAVE testing", messageID: "<a@x>", isFromMe: true, to: ["iqra@gmail.com"])
        let forward = message(id: "2", from: "ravi@icloud.com", subject: "Fwd: PAVE testing", messageID: "<b@x>", date: 10, isFromMe: true, to: ["iqra@gmail.com"])
        let answer = message(id: "3", from: "iqra@gmail.com", subject: "Re: Fwd: PAVE testing", messageID: "<c@x>", inReplyTo: "<b@x>", date: 20)
        let threads = EmailThreading.threads(from: [original, forward, answer])
        #expect(threads.count == 2)
        #expect(threads.contains { Set($0.messages.map(\.id)) == ["2", "3"] })
        #expect(EmailThreading.isForward("Re: FW: Stage"))
        #expect(!EmailThreading.isForward("Re: Stage"))
    }

    @Test func aForwardIsTakenApartForItsCard() {
        var original = EmailMessage(
            id: "1", provider: .icloud, location: .imap(folder: "INBOX", uid: 1),
            from: EmailAddress(name: "Renée", address: "renee@fontys.nl"), subject: "Stage", date: .now, isRead: true, isFromMe: false
        )
        original.body = "Ja, vanaf maart."
        let (note, parts) = EmailForward.split(EmailForward.body(note: "Kijk even", original: original))
        #expect(note == "Kijk even")
        #expect(parts.count == 1)
        #expect(parts.first?.from == "Renée")
        #expect(parts.first?.subject == "Stage")
        #expect(parts.first?.text == "Ja, vanaf maart.")
        let gmail = "Zie onder\n\n---------- Forwarded message ---------\nFrom: Noor <noor@x.nl>\nDate: Mon\nSubject: Les\nTo: <ravi@icloud.com>\n\nHoi"
        #expect(EmailForward.split(gmail).parts.first == EmailForward.Part(from: "Noor", address: "noor@x.nl", date: "Mon", subject: "Les", text: "Hoi"))
    }

    @Test func suggestionsShowNamesAndPutTheBestMatchFirst() async {
        let model = EmailModel(mailboxes: [FakeMailbox()])
        await model.refresh()
        let found = model.suggestedPeople(matching: "ren")
        #expect(found.first?.address == "renee@fontys.nl")
        #expect(found.first?.name == "Renée")
        #expect(model.suggestedPeople(matching: "renee@fontys.nl").isEmpty)
    }

    @Test func aForwardShowsItsNoteInTheList() {
        var forward = message(id: "1", from: "ravi@icloud.com", subject: "Fwd: Stage", isFromMe: true, to: ["noor@x.nl"])
        var original = message(id: "2", from: "renee@fontys.nl", subject: "Stage")
        original.body = "Hoi"
        forward.body = EmailForward.body(note: "", original: original)
        #expect(EmailModel.preview(of: EmailThread(id: "a", provider: .icloud, messages: [forward])) == "Jij: Doorgestuurd bericht")
        forward.body = EmailForward.body(note: "Kijk even", original: original)
        #expect(EmailModel.preview(of: EmailThread(id: "a", provider: .icloud, messages: [forward])) == "Jij: Kijk even")
    }

    @Test func theSummaryKnowsWhoWroteToWhom() {
        var asked = message(id: "1", from: "ravi@icloud.com", subject: "Stage", isFromMe: true, to: ["julie@bureau.nl"])
        asked.body = "Mag ik bij jullie stage lopen?"
        let material = EmailAylaTask.material(of: EmailThread(id: "a", provider: .icloud, messages: [asked]))
        #expect(material.contains("Van: Ik (de gebruiker)"))
        #expect(material.contains("Aan: julie <julie@bureau.nl>"))
    }

    @Test func betterWordingKeepsToWhatYouTypedAndTheMail() {
        let mail = message(id: "1", from: "renee@fontys.nl", subject: "Gesprek", to: ["ravi@icloud.com"])
        let thread = EmailThread(id: "icloud:1", provider: .icloud, messages: [mail])
        let question = EmailAylaTask.improve.question(for: thread, wish: " Ik kan morgen ochtend ")
        #expect(question.contains("\"Ik kan morgen ochtend\""))
        #expect(question.contains("Verzin geen"))
    }

    // MARK: Formatting

    @Test func onlyMailWithRealFormattingGetsTheButton() {
        #expect(EmailHTML.hasFormatting("<p>Hoi</p><table><tr><td>Ma</td></tr></table>"))
        #expect(EmailHTML.hasFormatting("<UL><li>a</li></UL>"))
        #expect(!EmailHTML.hasFormatting("<div>Hoi Ravi,</div><p>Tot morgen</p><br>"))
        #expect(!EmailHTML.hasFormatting("<p>Een tablet is handig</p>"))
    }

    @Test func theFormattedPageRunsNothingAndLoadsNothingUntilAsked() {
        let html = #"<p onclick="x()">Hoi</p><script>alert(1)</script><img src="https://track.example/p.gif">"#
        #expect(EmailHTML.hasRemoteImages(html))
        let page = EmailHTML.page(html, remoteImages: false)
        #expect(!page.contains("<script>"))
        #expect(page.contains("default-src 'none'"))
        #expect(page.contains("img-src data:;"))
        #expect(EmailHTML.page(html, remoteImages: true).contains("img-src data: https:"))
    }

    @Test func readsTheHTMLPartNextToThePlainText() {
        let raw = """
        From: school@fontys.nl
        Subject: Rooster
        Content-Type: multipart/alternative; boundary="B"

        --B
        Content-Type: text/plain; charset=utf-8

        Ma 9:00
        --B
        Content-Type: text/html; charset=utf-8

        <table><tr><td>Ma</td><td>9:00</td></tr></table>
        --B--
        """
        let mime = MIMEMessage(data: Data(raw.replacingOccurrences(of: "\n", with: "\r\n").utf8))
        #expect(mime.bodyText.contains("Ma 9:00"))
        #expect(mime.bodyHTML?.contains("<table>") == true)
    }

    // MARK: Vault

    @Test func aFileFromAMailStartsAsTheEvidenceItProbablyIs() {
        #expect(EmailVaultCategory.guess(fileName: "Certificaat Scrum.pdf", subject: "") == .certificates)
        #expect(EmailVaultCategory.guess(fileName: "contract.pdf", subject: "Je stagecontract") == .internships)
        #expect(EmailVaultCategory.guess(fileName: "Diploma.pdf", subject: "") == .diplomas)
        #expect(EmailVaultCategory.guess(fileName: "scan.pdf", subject: "Hoi") == .other)
    }

    // MARK: Muting and locking

    @Test func aMutedConversationGetsNoBanner() async throws {
        clearMarks()
        defer { clearMarks() }
        let mailbox = FakeMailbox()
        let model = EmailModel(mailboxes: [mailbox])
        await model.refresh()
        let id = try #require(model.visibleThreads.first?.id)
        model.toggleMute(id)
        #expect(model.notifications.first?.emailIsMuted == true)

        mailbox.extra = [newMail(id: "5", messageID: "<later@x>")]
        await model.refresh()
        #expect(model.banner == nil)
        #expect(model.arrivals.isEmpty)
        #expect(model.unreadCount == 1)

        model.toggleMute(id)
        mailbox.extra.append(newMail(id: "6", messageID: "<later2@x>"))
        await model.refresh()
        #expect(model.banner?.emailThreadID == id)
    }

    @Test func aLockedConversationShowsNothingUntilThePIN() async throws {
        clearMarks()
        defer { clearMarks() }
        let model = EmailModel(mailboxes: [FakeMailbox()])
        await model.refresh()
        let id = try #require(model.visibleThreads.first?.id)
        model.togglePin(id)
        model.setLocked(true, id)

        #expect(model.pinnedThreads.isEmpty)
        let row = try #require(model.notifications.first)
        #expect(row.title == "Vergrendeld gesprek")
        #expect(row.emailPeople.isEmpty)
        #expect(row.emailPreview == nil)
        #expect(model.threadIDs(matching: "Stage").isEmpty)
        #expect(model.threads(with: "renee@fontys.nl").isEmpty)

        model.showsLocked = true
        #expect(model.notifications.first?.title == "Stage")
        #expect(model.notifications.first?.emailIsLocked == true)
        #expect(model.threadIDs(matching: "Stage") == [id])

        model.setLocked(false, id)
        model.showsLocked = false
        #expect(model.notifications.first?.emailIsLocked == false)
    }

    @Test func theAppAndTheBackgroundNeverAnnounceTheSameMailTwice() async {
        clearMarks()
        defer { clearMarks() }
        let mailbox = FakeMailbox()
        let app = EmailModel(mailboxes: [mailbox])
        await app.refresh()
        #expect(app.arrivals.isEmpty)

        mailbox.extra = [newMail(id: "5", messageID: "<later@x>")]
        let background = EmailModel(mailboxes: [mailbox])
        await background.refresh(previews: false)
        #expect(background.arrivals.count == 1)

        await app.refresh()
        #expect(app.banner == nil)
    }

    @Test func aylaGetsTheSubjectAndTheTextOfTheMail() {
        var mail = message(id: "1", from: "renee@fontys.nl", subject: "Stage", to: ["ravi@icloud.com"])
        mail.body = "Kun je donderdag?"
        let thread = EmailThread(id: "icloud:1", provider: .icloud, messages: [mail])
        let material = EmailAylaTask.material(of: thread)
        #expect(material.hasPrefix("Onderwerp: Stage"))
        #expect(material.contains("Kun je donderdag?"))
        #expect(EmailAylaTask.suggestReply.question(for: thread, wish: "ja").contains("Wat ik wil zeggen: ja."))
    }

    // MARK: Helpers

    private func clearMarks() {
        for key in [EmailModel.mutedKey, EmailModel.lockedKey, EmailModel.pinnedKey, EmailModel.seenKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// A new unread answer from Renée in the conversation about Stage.
    private func newMail(id: String, messageID: String) -> EmailMessage {
        EmailMessage(
            id: id, provider: .icloud, location: .imap(folder: "INBOX", uid: UInt32(id) ?? 1), messageID: messageID,
            inReplyTo: "<a@x>", references: ["<z@x>", "<a@x>"],
            from: EmailAddress(name: "Renée", address: "renee@fontys.nl"), to: [EmailAddress(name: nil, address: "ravi@icloud.com")],
            subject: "Re: Stage", date: .now, isRead: false, isFromMe: false
        )
    }

    private func message(
        id: String, from: String, subject: String, messageID: String? = nil, inReplyTo: String? = nil,
        references: [String] = [], date: TimeInterval = 0, isFromMe: Bool = false, to: [String] = ["ravi@icloud.com"]
    ) -> EmailMessage {
        EmailMessage(
            id: id, provider: .icloud, location: .imap(folder: "INBOX", uid: UInt32(id) ?? 1),
            messageID: messageID, inReplyTo: inReplyTo, references: references,
            from: EmailAddress(name: nil, address: from), to: to.map { EmailAddress(name: nil, address: $0) },
            subject: subject, date: Date(timeIntervalSince1970: date), isRead: isFromMe, isFromMe: isFromMe
        )
    }
}

private final class FakeMailbox: EmailMailbox {
    let account = EmailAccount(provider: .icloud, address: "ravi@icloud.com")
    var markedRead: [String] = []
    var replies: [String] = []
    var trashed: [String] = []
    var restored: [EmailTrashedMessage] = []
    /// Who each reply went to.
    var recipients: [[String]] = []
    /// Also on Renée's message, for "Allen antwoorden".
    var extraRecipients: [String] = []
    /// Mail that arrives later in a test.
    var extra: [EmailMessage] = []
    /// Fixed, so the mail is older than what the test sends, like a real mailbox.
    private let now = Date.now.addingTimeInterval(-300)

    func recentMessages() async throws -> [EmailMessage] {
        let renee = EmailAddress(name: "Renée", address: "renee@fontys.nl")
        return [
            EmailMessage(
                id: "0", provider: .icloud, location: .imap(folder: "Sent Messages", uid: 9), messageID: "<z@x>",
                from: EmailAddress(name: nil, address: account.address), to: [renee],
                subject: "Stage", date: now.addingTimeInterval(-60), isRead: true, isFromMe: true
            ),
            EmailMessage(
                id: "1", provider: .icloud, location: .imap(folder: "INBOX", uid: 1), messageID: "<a@x>", inReplyTo: "<z@x>",
                from: renee, to: [EmailAddress(name: nil, address: account.address)] + extraRecipients.map { EmailAddress(name: nil, address: $0) },
                subject: "Re: Stage", date: now, isRead: false, isFromMe: false
            ),
            EmailMessage(
                id: "2", provider: .icloud, location: .imap(folder: "INBOX", uid: 2), messageID: "<n@x>",
                from: EmailAddress(name: nil, address: "noreply@winkel.nl"), subject: "Aanbieding", date: now,
                isRead: false, isFromMe: false, isAutomated: true
            ),
        ] + extra
    }

    func load(_ messages: [EmailMessage]) async throws -> [EmailMessage] {
        messages.map { var copy = $0; copy.body = $0.isFromMe ? "Kan ik stage lopen?" : "Hoi Ravi"; return copy }
    }

    func attachmentData(_ attachment: EmailAttachment, of message: EmailMessage) async throws -> Data { Data() }

    func markRead(_ messages: [EmailMessage]) async throws { markedRead += messages.map(\.id) }

    func send(to recipients: [EmailAddress], subject: String, text: String, attachments: [EmailOutgoingAttachment]) async throws -> EmailSent {
        replies.append(text)
        return EmailSent(messageID: "<new@icloud.com>")
    }

    func reply(to message: EmailMessage, recipients: EmailReplyRecipients, text: String, attachments: [EmailOutgoingAttachment]) async throws -> EmailSent {
        replies.append(text)
        self.recipients.append(recipients.everyone.map(\.address))
        return EmailSent(messageID: "<reply-\(replies.count)@icloud.com>")
    }

    func disconnect() async {}
    func setSenderName(_ name: String?) {}
    func trash(_ messages: [EmailMessage]) async throws { trashed += messages.map(\.id) }
    func restore(_ messages: [EmailTrashedMessage]) async throws { restored += messages }
}
