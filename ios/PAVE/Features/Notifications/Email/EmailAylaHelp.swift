import Foundation
import PAVECore

/// Ayla helps with a mail: a short summary, or a reply that lands in your reply field to change. The text only goes to
/// Ayla after you said yes once (`EmailThreadScreen`), and the chat she needs for it is deleted again right after.
nonisolated enum EmailAylaTask: String, Identifiable, Sendable {
    case summarize
    case suggestReply
    /// "Beter formuleren": what you typed, said well, as an answer to this mail.
    case improve

    var id: Self { self }

    var title: String {
        switch self {
        case .summarize: "Samenvatten"
        case .suggestReply: "Antwoord voorstellen"
        case .improve: "Beter formuleren"
        }
    }

    /// The most recent messages, oldest first, within what Ayla takes for one file. Who sent each one and to whom is
    /// spelled out, with "Ik" for the user, so she cannot mix up who asks what of whom.
    static func material(of thread: EmailThread) -> String {
        func person(_ address: EmailAddress, mine: Bool) -> String {
            mine ? "Ik (de gebruiker)" : "\(address.displayName) <\(address.address)>"
        }
        let blocks = thread.messages.sorted { $0.date < $1.date }.suffix(8).map { message in
            let me = Set(thread.messages.filter(\.isFromMe).map { $0.from.address.lowercased() })
            let from = person(message.from, mine: message.isFromMe)
            let to = (message.to + message.cc).map { person($0, mine: me.contains($0.address.lowercased())) }
            let when = message.date.formatted(.dateTime.weekday(.wide).day().month().year().hour().minute().locale(Locale(identifier: "nl_NL")))
            let files = message.attachments.map(\.name)
            var lines = ["Van: \(from)"]
            if !to.isEmpty { lines.append("Aan: \(to.joined(separator: ", "))") }
            lines.append("Datum: \(when)")
            if !files.isEmpty { lines.append("Bijlagen: \(files.joined(separator: ", "))") }
            return lines.joined(separator: "\n") + "\n\n" + (message.body ?? "")
        }
        let subject = thread.subject.isEmpty ? "" : "Onderwerp: \(thread.subject)\n\n"
        let text = subject + blocks.joined(separator: "\n\n---\n\n")
        return String(text.suffix(AylaAttachment.maxTextLength - 100))
    }

    /// Ayla may only use what is in the mail and in what you typed: an invented date or promise would go out in your name.
    private static let noInventing = "Verzin geen afspraken, tijden, namen, feiten of beloftes die niet in de mail of in mijn tekst staan. Weet je iets niet, laat dan een korte open plek zoals [dag]."

    func question(for thread: EmailThread, wish: String) -> String {
        let to = thread.messages.last { !$0.isFromMe }?.from.displayName ?? thread.participantNames
        let wish = wish.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .summarize:
            let today = Date.now.formatted(.dateTime.weekday(.wide).day().month().year().locale(Locale(identifier: "nl_NL")))
            return """
            Vat het e-mailgesprek in het bestand voor mij samen. Bij elk bericht staat wie het stuurde en aan wie; "Ik (de gebruiker)" ben ik, alle anderen zijn andere mensen. Vandaag is het \(today).

            Denk eerst na voordat je schrijft: wie schreef wie, wie vraagt of biedt wat aan wie, en wie stuurde het laatste bericht. Haal mij en de ander nooit door elkaar: heb ik zelf iets gevraagd, dan schrijf je "Je vroeg {naam} …", vraagt de ander iets, dan "{naam} vraagt je …".

            Schrijf in de je-vorm tegen mij, in gewone taal, in hooguit drie korte zinnen:
            1. Waar het over gaat en wie wat wil.
            2. Hoe het nu staat: wacht ik op antwoord van iemand, of wacht iemand op mij?
            3. Wat ik nog moet doen en wanneer, maar alleen als dat er echt staat.
            Noem alleen wat er staat; zeg niet wat er ontbreekt en verzin niets. Geef alleen de samenvatting, zonder kopjes of nummers.
            """
        case .suggestReply:
            let what = wish.isEmpty ? "" : " Wat ik wil zeggen: \(wish)."
            return "Schrijf een kort, vriendelijk antwoord op de laatste e-mail van \(to) in het bestand, in de taal van die mail, dat ik zo kan versturen.\(what) Lees eerst goed waar de mail over gaat en antwoord daarop. \(Self.noInventing) Geef alleen de tekst van het antwoord, zonder onderwerp en zonder uitleg."
        case .improve:
            return "Ik antwoord op de laatste e-mail van \(to) in het bestand. Dit heb ik getypt: \"\(wish)\". Lees eerst waar de mail over gaat. Maak van mijn tekst een duidelijk, vriendelijk en foutloos antwoord op die mail, in de taal van de mail, met een aanhef en afsluiting die passen bij hoe \(to) schrijft. Houd precies wat ik bedoel; maak het niet veel langer. \(Self.noInventing) Geef alleen de tekst van het antwoord, zonder onderwerp en zonder uitleg."
        }
    }
}

/// Asks Ayla once, outside your chats: the conversation the server makes for it is removed again.
nonisolated struct EmailAylaHelper: Sendable {
    let service: any AylaService

    func run(_ task: EmailAylaTask, on thread: EmailThread, wish: String = "") async throws -> String {
        guard let file = AylaAttachment(name: "E-mail.txt", text: EmailAylaTask.material(of: thread)) else {
            throw EmailError.server("Deze mail heeft geen tekst voor Ayla.")
        }
        let request = AylaRequest(text: task.question(for: thread, wish: wish), device: .phone, input: .text, attachments: [file])
        let reply = try await service.send(request)
        try? await service.delete(conversationID: reply.conversationId)
        let text = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw EmailError.server("Ayla gaf geen antwoord. Probeer het opnieuw.") }
        return text
    }
}
