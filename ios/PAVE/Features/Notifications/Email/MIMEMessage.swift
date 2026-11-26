import Foundation

/// Just enough of MIME (RFC 2045–2047, 2231) to read a message's text and attachments, and to write a reply.
nonisolated struct MIMEMessage: Sendable {
    struct Header: Sendable {
        let name: String
        let value: String
    }

    struct Part: Sendable {
        let headers: [Header]
        let body: Data

        func header(_ name: String) -> String? {
            headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        var contentType: MIMEContentType {
            MIMEContentType(header("Content-Type") ?? "text/plain; charset=us-ascii")
        }

        var disposition: MIMEContentType? {
            header("Content-Disposition").map(MIMEContentType.init)
        }

        var fileName: String? {
            (disposition?.parameters["filename"] ?? contentType.parameters["name"]).map(MIMEMessage.decodeWords)
        }

        /// The bytes after undoing base64 or quoted-printable.
        var decodedBody: Data {
            switch header("Content-Transfer-Encoding")?.trimmingCharacters(in: .whitespaces).lowercased() {
            case "base64":
                let compact = body.filter { !($0 == 0x0A || $0 == 0x0D || $0 == 0x20 || $0 == 0x09) }
                return Data(base64Encoded: compact, options: .ignoreUnknownCharacters) ?? Data()
            case "quoted-printable":
                return MIMEMessage.decodeQuotedPrintable(body)
            default:
                return body
            }
        }

        var text: String {
            MIMEMessage.string(from: decodedBody, charset: contentType.parameters["charset"])
        }

        var children: [Part] {
            guard contentType.type == "multipart", let boundary = contentType.parameters["boundary"] else { return [] }
            return MIMEMessage.split(body, boundary: boundary).map(MIMEMessage.parsePart)
        }
    }

    let root: Part

    init(data: Data) {
        root = Self.parsePart(data)
    }

    // MARK: What the app needs

    var subject: String { root.header("Subject").map(Self.decodeWords) ?? "" }
    var from: EmailAddress? { root.header("From").flatMap { Self.addresses($0).first } }
    var to: [EmailAddress] { root.header("To").map(Self.addresses) ?? [] }
    var cc: [EmailAddress] { root.header("Cc").map(Self.addresses) ?? [] }
    var messageID: String? { root.header("Message-ID").flatMap { Self.messageIDs($0).first } }
    var inReplyTo: String? { root.header("In-Reply-To").flatMap { Self.messageIDs($0).first } }
    var references: [String] { root.header("References").map(Self.messageIDs) ?? [] }
    var date: Date? { root.header("Date").flatMap(Self.date) }

    /// Mail that no person wrote: a mailing list, a newsletter, an automatic notice or a no-reply sender.
    var isAutomated: Bool {
        if root.header("List-Unsubscribe") != nil || root.header("List-Id") != nil { return true }
        if let precedence = root.header("Precedence")?.lowercased(), ["bulk", "list", "junk"].contains(precedence) { return true }
        if let auto = root.header("Auto-Submitted")?.lowercased(), auto != "no" { return true }
        let sender = from?.address.lowercased().split(separator: "@").first.map(String.init) ?? ""
        let machines = ["noreply", "no-reply", "donotreply", "do-not-reply", "mailer-daemon", "notifications", "notification", "newsletter", "nieuwsbrief"]
        return machines.contains(sender) || sender.hasPrefix("noreply") || sender.hasPrefix("no-reply")
    }

    /// The plain text if there is one, otherwise the HTML turned into text.
    var bodyText: String {
        var plain: String?
        var html: String?
        func walk(_ part: Part) {
            let type = part.contentType
            if type.type == "multipart" {
                part.children.forEach(walk)
                return
            }
            guard !isAttachment(part, insideRelated: false), type.type == "text" else { return }
            if type.subtype == "plain", plain == nil { plain = part.text }
            if type.subtype == "html", html == nil { html = part.text }
        }
        walk(root)
        return plain ?? html.map(Self.textFromHTML) ?? ""
    }

    /// The HTML part, if the message has one.
    var bodyHTML: String? {
        var html: String?
        func walk(_ part: Part) {
            let type = part.contentType
            if type.type == "multipart" {
                part.children.forEach(walk)
                return
            }
            guard html == nil, !isAttachment(part, insideRelated: false), type.type == "text", type.subtype == "html" else { return }
            html = part.text
        }
        walk(root)
        return html
    }

    var attachments: [EmailAttachment] {
        var result: [EmailAttachment] = []
        func walk(_ part: Part, insideRelated: Bool) {
            let type = part.contentType
            if type.type == "multipart" {
                part.children.forEach { walk($0, insideRelated: insideRelated || type.subtype == "related") }
                return
            }
            guard isAttachment(part, insideRelated: insideRelated) else { return }
            let data = part.decodedBody
            let name = part.fileName ?? "Bijlage \(result.count + 1)"
            result.append(EmailAttachment(id: "\(result.count)", name: name, mimeType: type.mimeType, size: data.count, data: data))
        }
        walk(root, insideRelated: false)
        return result
    }

    /// A part is a file unless it is the text itself, or a picture that only decorates the HTML (a logo in a signature).
    private func isAttachment(_ part: Part, insideRelated: Bool) -> Bool {
        let type = part.contentType
        let disposition = part.disposition?.mimeType
        if disposition == "attachment" { return true }
        if insideRelated, part.header("Content-ID") != nil { return false }
        if type.type == "text", (type.subtype == "plain" || type.subtype == "html"), part.fileName == nil { return false }
        return part.fileName != nil || type.type != "text"
    }

    // MARK: Parsing

    static func parsePart(_ data: Data) -> Part {
        let bytes = [UInt8](data)
        // A part without headers starts with the empty line right away.
        if bytes.starts(with: [0x0D, 0x0A]) { return Part(headers: [], body: Data(bytes[2...])) }
        if bytes.first == 0x0A { return Part(headers: [], body: Data(bytes[1...])) }
        var split: Int?
        var bodyStart = bytes.count
        var index = 0
        while index < bytes.count {
            if bytes[index] == 0x0A {
                if index + 1 < bytes.count, bytes[index + 1] == 0x0A { split = index; bodyStart = index + 2; break }
                if index + 2 < bytes.count, bytes[index + 1] == 0x0D, bytes[index + 2] == 0x0A { split = index; bodyStart = index + 3; break }
            }
            index += 1
        }
        let headerBytes = split.map { Array(bytes[..<$0]) } ?? bytes
        let body = split == nil ? Data() : Data(bytes[min(bodyStart, bytes.count)...])
        let headerText = String(decoding: headerBytes, as: UTF8.self).trimmingCharacters(in: .newlines)
        var headers: [Header] = []
        for line in headerText.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if let first = line.first, first == " " || first == "\t", let last = headers.popLast() {
                headers.append(Header(name: last.name, value: last.value + " " + line.trimmingCharacters(in: .whitespacesAndNewlines)))
            } else if let colon = line.firstIndex(of: ":") {
                headers.append(Header(
                    name: String(line[..<colon]).trimmingCharacters(in: .whitespaces),
                    value: String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            }
        }
        if split == nil, headers.isEmpty { return Part(headers: [], body: data) }
        return Part(headers: headers, body: body)
    }

    static func split(_ body: Data, boundary: String) -> [Data] {
        let delimiter = Array("--\(boundary)".utf8)
        let bytes = [UInt8](body)
        var parts: [Data] = []
        var start: Int?
        var lineStart = 0
        while lineStart <= bytes.count {
            var lineEnd = lineStart
            while lineEnd < bytes.count, bytes[lineEnd] != 0x0A { lineEnd += 1 }
            let line = bytes[lineStart..<lineEnd]
            if line.starts(with: delimiter) {
                if let start {
                    var end = lineStart
                    if end > start, bytes[end - 1] == 0x0A { end -= 1 }
                    if end > start, bytes[end - 1] == 0x0D { end -= 1 }
                    parts.append(Data(bytes[start..<max(start, end)]))
                }
                let rest = line.dropFirst(delimiter.count)
                if rest.starts(with: [0x2D, 0x2D]) { return parts }
                start = lineEnd + 1
            }
            lineStart = lineEnd + 1
        }
        if let start, start < bytes.count { parts.append(Data(bytes[start...])) }
        return parts
    }

    static func decodeQuotedPrintable(_ data: Data) -> Data {
        let bytes = [UInt8](data)
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var index = 0
        func hex(_ byte: UInt8) -> UInt8? {
            switch byte {
            case 0x30...0x39: byte - 0x30
            case 0x41...0x46: byte - 0x41 + 10
            case 0x61...0x66: byte - 0x61 + 10
            default: nil
            }
        }
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x3D {
                if index + 1 < bytes.count, bytes[index + 1] == 0x0A { index += 2; continue }
                if index + 2 < bytes.count, bytes[index + 1] == 0x0D, bytes[index + 2] == 0x0A { index += 3; continue }
                if index + 2 < bytes.count, let high = hex(bytes[index + 1]), let low = hex(bytes[index + 2]) {
                    output.append(high << 4 | low)
                    index += 3
                    continue
                }
            }
            output.append(byte)
            index += 1
        }
        return Data(output)
    }

    static func string(from data: Data, charset: String?) -> String {
        if let charset {
            let cf = CFStringConvertIANACharSetNameToEncoding(charset.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) as CFString)
            if cf != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
                if let value = String(data: data, encoding: encoding) { return value }
            }
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) ?? String(decoding: data, as: UTF8.self)
    }

    /// "=?utf-8?Q?Caf=C3=A9?=" becomes "Café"; words next to each other join without the space between them.
    static func decodeWords(_ value: String) -> String {
        let pattern = #"=\?([^?]+)\?([bBqQ])\?([^?]*)\?="#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let source = value as NSString
        var result = ""
        var cursor = 0
        var lastWasEncoded = false
        for match in regex.matches(in: value, range: NSRange(location: 0, length: source.length)) {
            let between = source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            if !(lastWasEncoded && between.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { result += between }
            let charset = source.substring(with: match.range(at: 1)).components(separatedBy: "*").first
            let encoding = source.substring(with: match.range(at: 2)).lowercased()
            let text = source.substring(with: match.range(at: 3))
            let data: Data
            if encoding == "b" {
                data = Data(base64Encoded: text, options: .ignoreUnknownCharacters) ?? Data()
            } else {
                data = decodeQuotedPrintable(Data(text.replacingOccurrences(of: "_", with: " ").utf8))
            }
            result += string(from: data, charset: charset)
            cursor = match.range.location + match.range.length
            lastWasEncoded = true
        }
        result += source.substring(from: cursor)
        return result
    }

    /// "Ravi <ravi@x.nl>, \"Noor, El\" <noor@y.nl>, z@z.nl".
    static func addresses(_ value: String) -> [EmailAddress] {
        var items: [String] = []
        var current = ""
        var inQuotes = false
        var inAngle = false
        for character in value {
            switch character {
            case "\"": inQuotes.toggle(); current.append(character)
            case "<": inAngle = true; current.append(character)
            case ">": inAngle = false; current.append(character)
            case "," where !inQuotes && !inAngle:
                items.append(current)
                current = ""
            default: current.append(character)
            }
        }
        items.append(current)
        return items.compactMap { raw in
            let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty else { return nil }
            if let open = item.lastIndex(of: "<"), let close = item.lastIndex(of: ">"), open < close {
                let address = String(item[item.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
                let name = decodeWords(String(item[..<open]))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\" ").union(.whitespaces))
                return address.contains("@") ? EmailAddress(name: name.isEmpty ? nil : name, address: address) : nil
            }
            let address = item.components(separatedBy: " ").first { $0.contains("@") } ?? item
            return address.contains("@") ? EmailAddress(name: nil, address: address) : nil
        }
    }

    static func messageIDs(_ value: String) -> [String] {
        let pattern = #"<[^<>\s]+>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let source = value as NSString
        return regex.matches(in: value, range: NSRange(location: 0, length: source.length)).map { source.substring(with: $0.range) }
    }

    static func date(_ value: String) -> Date? {
        let cleaned = value
            .replacingOccurrences(of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, d MMM yyyy HH:mm:ss Z", "d MMM yyyy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm Z", "EEE, d MMM yy HH:mm:ss Z", "d-MMM-yyyy HH:mm:ss Z"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) { return date }
        }
        return nil
    }

    static func textFromHTML(_ html: String) -> String {
        var text = html
        let replacements: [(String, String)] = [
            (#"(?is)<(script|style|head)[^>]*>.*?</\1>"#, ""),
            (#"(?i)<br\s*/?>"#, "\n"),
            (#"(?i)</(p|div|li|tr|h[1-6])>"#, "\n"),
            (#"(?s)<[^>]+>"#, ""),
            (#"[ \t]+"#, " "),
            (#"\n\s*\n\s*\n+"#, "\n\n"),
        ]
        for (pattern, replacement) in replacements {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"]
        for (entity, value) in entities { text = text.replacingOccurrences(of: entity, with: value) }
        text = text.replacingOccurrences(of: #"&#(\d+);"#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated struct MIMEContentType: Sendable {
    let type: String
    let subtype: String
    let parameters: [String: String]

    var mimeType: String { "\(type)/\(subtype)" }

    init(_ value: String) {
        var pieces: [String] = []
        var current = ""
        var inQuotes = false
        for character in value {
            if character == "\"" { inQuotes.toggle() }
            if character == ";", !inQuotes {
                pieces.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        pieces.append(current)
        let full = pieces.first?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let halves = full.split(separator: "/", maxSplits: 1)
        type = halves.first.map(String.init) ?? full
        subtype = halves.count > 1 ? String(halves[1]) : ""

        var raw: [String: String] = [:]
        for piece in pieces.dropFirst() {
            guard let equals = piece.firstIndex(of: "=") else { continue }
            let key = piece[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            var value = piece[piece.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 { value = String(value.dropFirst().dropLast()) }
            raw[key] = value
        }
        // RFC 2231: name*=utf-8''Caf%C3%A9.pdf, possibly split over name*0*, name*1*, …
        var result: [String: String] = [:]
        var continued: [String: [(Int, String, Bool)]] = [:]
        for (key, value) in raw {
            let segments = key.split(separator: "*", omittingEmptySubsequences: false).map(String.init)
            if segments.count == 1 {
                result[key] = value
            } else if segments.count == 2, segments[1].isEmpty {
                result[segments[0]] = Self.decode2231(value, extended: true)
            } else if let index = Int(segments[1]) {
                continued[segments[0], default: []].append((index, value, segments.count == 3))
            }
        }
        for (key, items) in continued {
            let sorted = items.sorted { $0.0 < $1.0 }
            let extended = sorted.first?.2 ?? false
            let joined = sorted.map(\.1).joined()
            result[key] = extended ? Self.decode2231(joined, extended: true) : joined
        }
        parameters = result
    }

    private static func decode2231(_ value: String, extended: Bool) -> String {
        let parts = value.components(separatedBy: "'")
        let charset = parts.count >= 3 ? parts[0] : "utf-8"
        let encoded = parts.count >= 3 ? parts[2...].joined(separator: "'") : value
        var bytes: [UInt8] = []
        var index = encoded.startIndex
        while index < encoded.endIndex {
            if encoded[index] == "%", let end = encoded.index(index, offsetBy: 3, limitedBy: encoded.endIndex),
               let byte = UInt8(encoded[encoded.index(after: index)..<end], radix: 16) {
                bytes.append(byte)
                index = end
            } else {
                bytes.append(contentsOf: Array(String(encoded[index]).utf8))
                index = encoded.index(after: index)
            }
        }
        return MIMEMessage.string(from: Data(bytes), charset: charset.isEmpty ? "utf-8" : charset)
    }
}

/// Writes a reply as a complete RFC 5322 message, for SMTP and for the copy in "Verzonden".
nonisolated enum MIMEBuilder {
    static func reply(
        from: EmailAddress,
        to: [EmailAddress],
        cc: [EmailAddress],
        subject: String,
        text: String,
        quoting original: EmailMessage?,
        attachments: [EmailOutgoingAttachment],
        date: Date = .now
    ) -> (data: Data, messageID: String) {
        let domain = from.address.split(separator: "@").last.map(String.init) ?? "pave.local"
        let messageID = "<\(UUID().uuidString.lowercased())@\(domain)>"
        var headers = [
            "From: \(format(from))",
            "To: \(to.map(format).joined(separator: ", "))",
        ]
        if !cc.isEmpty { headers.append("Cc: \(cc.map(format).joined(separator: ", "))") }
        headers += [
            "Subject: \(encodeWord(subject))",
            "Date: \(rfc2822(date))",
            "Message-ID: \(messageID)",
            "MIME-Version: 1.0",
        ]
        if let original, let id = original.messageID {
            headers.append("In-Reply-To: \(id)")
            let chain = (original.references + [id]).suffix(20)
            headers.append("References: \(chain.joined(separator: " "))")
        }

        var body = text
        if let original {
            let when = original.date.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "nl_NL")))
            let quoted = (original.body ?? "").components(separatedBy: "\n").map { "> \($0)" }.joined(separator: "\n")
            body += "\n\nOp \(when) schreef \(original.from.displayName) <\(original.from.address)>:\n\(quoted)"
        }
        // Quoted-printable, not base64: the text stays readable, which spam filters trust more.
        let textPart = [
            "Content-Type: text/plain; charset=utf-8",
            "Content-Transfer-Encoding: quoted-printable",
            "",
            quotedPrintable(body),
        ].joined(separator: "\r\n")

        var message = headers.joined(separator: "\r\n") + "\r\n"
        if attachments.isEmpty {
            message += textPart + "\r\n"
        } else {
            let boundary = "PAVE-\(UUID().uuidString)"
            message += "Content-Type: multipart/mixed; boundary=\"\(boundary)\"\r\n\r\n"
            message += "--\(boundary)\r\n\(textPart)\r\n"
            for file in attachments {
                let name = file.name.replacingOccurrences(of: "\"", with: "'")
                message += "--\(boundary)\r\n"
                message += "Content-Type: \(file.mimeType); name=\"\(encodeWord(name))\"\r\n"
                message += "Content-Disposition: attachment; filename=\"\(encodeWord(name))\"\r\n"
                message += "Content-Transfer-Encoding: base64\r\n\r\n"
                message += wrappedBase64(file.data) + "\r\n"
            }
            message += "--\(boundary)--\r\n"
        }
        return (Data(message.utf8), messageID)
    }

    static func format(_ address: EmailAddress) -> String {
        guard let name = address.name, !name.isEmpty else { return address.address }
        let isPlain = name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == " " || $0 == "-" || $0 == ".") }
        return isPlain ? "\(name) <\(address.address)>" : "\(encodeWord(name)) <\(address.address)>"
    }

    static func encodeWord(_ value: String) -> String {
        guard !value.allSatisfy({ $0.isASCII }) else { return value }
        return "=?utf-8?B?\(Data(value.utf8).base64EncodedString())?="
    }

    /// RFC 2045 quoted-printable, lines of at most 76 characters.
    static func quotedPrintable(_ text: String) -> String {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        return lines.map { line -> String in
            var encoded: [String] = []
            let bytes = Array(line.utf8)
            for (index, byte) in bytes.enumerated() {
                let isLast = index == bytes.count - 1
                let plain = (byte >= 33 && byte <= 126 && byte != 61) || ((byte == 32 || byte == 9) && !isLast)
                encoded.append(plain ? String(UnicodeScalar(byte)) : String(format: "=%02X", byte))
            }
            var result = ""
            var width = 0
            for piece in encoded {
                if width + piece.count > 75 {
                    result += "=\r\n"
                    width = 0
                }
                result += piece
                width += piece.count
            }
            return result
        }
        .joined(separator: "\r\n")
    }

    static func wrappedBase64(_ data: Data) -> String {
        data.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])
    }

    static func rfc2822(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        return formatter.string(from: date)
    }
}
