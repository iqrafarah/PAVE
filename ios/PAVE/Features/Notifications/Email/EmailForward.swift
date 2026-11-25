import Foundation

/// "Doorsturen": a new mail with your note on top and the original under it, as Mail writes it.
nonisolated enum EmailForward {
    static let marker = "---------- Doorgestuurd bericht ----------"
    /// PAVE's own line, Gmail's and Outlook's, so their forwards read the same.
    private static let markerPattern = #"-{5,}\s*(Doorgestuurd bericht|Forwarded message|Original Message|Oorspronkelijk bericht)\s*-{5,}"#

    /// One forwarded message, as it is shown in the conversation: who, when, and its text.
    struct Part: Equatable {
        var from = ""
        var address = ""
        var date = ""
        var subject = ""
        var text = ""
    }

    /// What you wrote above a forwarded message, and whether there is one: the list shows that instead of the headers.
    static func note(in body: String) -> (note: String, isForwarded: Bool) {
        let (note, parts) = split(body)
        return (note, !parts.isEmpty)
    }

    /// The note, and each forwarded message with its header lines taken apart.
    static func split(_ body: String) -> (note: String, parts: [Part]) {
        let markers = body.ranges(of: try! Regex(markerPattern).ignoresCase())
        guard let first = markers.first else { return (body, []) }
        let note = String(body[..<first.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [Part] = []
        for (index, marker) in markers.enumerated() {
            let end = index + 1 < markers.count ? markers[index + 1].lowerBound : body.endIndex
            parts.append(part(String(body[marker.upperBound..<end])))
        }
        return (note, parts)
    }

    private static func part(_ chunk: String) -> Part {
        var part = Part()
        var lines = chunk.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        let headers: [(String, WritableKeyPath<Part, String>)] = [
            ("van:", \.from), ("from:", \.from), ("datum:", \.date), ("date:", \.date), ("sent:", \.date),
            ("onderwerp:", \.subject), ("subject:", \.subject), ("aan:", \.subject), ("to:", \.subject), ("cc:", \.subject),
        ]
        while let line = lines.first, !line.trimmingCharacters(in: .whitespaces).isEmpty,
              let header = headers.first(where: { line.lowercased().hasPrefix($0.0) }) {
            let value = line.dropFirst(header.0.count).trimmingCharacters(in: .whitespaces)
            // To and Cc are read past; they do not need a place on the card.
            if !["aan:", "to:", "cc:"].contains(header.0) { part[keyPath: header.1] = value }
            lines.removeFirst()
        }
        part.text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        // "Iqra <iqra@icloud.com>" shows as "Iqra", with the address kept for the photo.
        if let open = part.from.firstIndex(of: "<"), let close = part.from.lastIndex(of: ">"), open < close {
            part.address = String(part.from[part.from.index(after: open)..<close])
            let name = part.from[..<open].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            part.from = name.isEmpty ? part.address : name
        } else if part.from.contains("@") {
            part.address = part.from
        }
        return part
    }

    static func subject(_ original: String) -> String {
        let clean = EmailThreading.normalizedSubject(original)
        return clean.isEmpty ? "Fwd:" : "Fwd: \(clean)"
    }

    static func body(note: String, original message: EmailMessage) -> String {
        body(note: note, messages: [message])
    }

    /// A whole conversation: every message with its own header, oldest first, as each holds only its new part.
    static func body(note: String, messages: [EmailMessage]) -> String {
        let original = messages.sorted { $0.date < $1.date }.map(block).joined(separator: "\n\n")
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? original : "\(note)\n\n\(original)"
    }

    /// "Renée <renee@fontys.nl>", as people read it; MIMEBuilder's form is for headers and encodes the name.
    private static func readable(_ address: EmailAddress) -> String {
        guard let name = address.name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return address.address }
        return "\(name) <\(address.address)>"
    }

    private static func block(_ message: EmailMessage) -> String {
        let locale = Locale(identifier: "nl_NL")
        let when = message.date.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(locale))
        var lines = [
            marker,
            "Van: \(readable(message.from))",
            "Datum: \(when)",
        ]
        if !message.subject.isEmpty { lines.append("Onderwerp: \(message.subject)") }
        if !message.to.isEmpty { lines.append("Aan: \(message.to.map(readable).joined(separator: ", "))") }
        if !message.cc.isEmpty { lines.append("Cc: \(message.cc.map(readable).joined(separator: ", "))") }
        return lines.joined(separator: "\n") + "\n\n" + (message.body ?? "")
    }
}

/// What "Doorsturen" sends along: one message you held, or the whole conversation from the ⋯ menu.
struct EmailForwarding: Identifiable {
    let id = UUID()
    let messages: [EmailMessage]

    var subject: String { messages.min { $0.date < $1.date }?.subject ?? "" }
}
