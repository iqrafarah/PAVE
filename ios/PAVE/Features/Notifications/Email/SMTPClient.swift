import Foundation

/// Sends one message over SMTP with STARTTLS and AUTH PLAIN, as iCloud expects on port 587.
final class SMTPClient {
    private let connection: MailConnection

    init(host: String, port: Int = 587) {
        connection = MailConnection(host: host, port: port, implicitTLS: false)
    }

    func send(_ message: Data, from sender: String, to recipients: [String], user: String, password: String) async throws {
        defer { connection.close() }
        try await expect(220)
        try await command("EHLO pave.local", expecting: 250)
        try await command("STARTTLS", expecting: 220)
        connection.startTLS()
        try await command("EHLO pave.local", expecting: 250)
        let credentials = Data("\u{0}\(user)\u{0}\(password)".utf8).base64EncodedString()
        do {
            try await command("AUTH PLAIN \(credentials)", expecting: 235)
        } catch is ReplyError {
            throw EmailError.wrongPassword
        }
        try await command("MAIL FROM:<\(sender)>", expecting: 250)
        for recipient in recipients {
            try await command("RCPT TO:<\(recipient)>", expecting: 250, 251)
        }
        try await command("DATA", expecting: 354)
        try await connection.write(Self.dotStuffed(message))
        try await connection.write(".\r\n")
        try await expect(250)
        try? await connection.write("QUIT\r\n")
    }

    struct ReplyError: Error {
        let code: Int
        let text: String
    }

    private func command(_ text: String, expecting codes: Int...) async throws {
        try await connection.write(text + "\r\n")
        try await expect(codes)
    }

    private func expect(_ codes: Int...) async throws {
        try await expect(codes)
    }

    /// Reads a reply, which may span several "250-…" lines, and checks its code.
    private func expect(_ codes: [Int]) async throws {
        var lines: [String] = []
        while true {
            let line = String(decoding: try await connection.readLine(), as: UTF8.self)
            lines.append(line)
            if line.count < 4 || line[line.index(line.startIndex, offsetBy: 3)] != "-" { break }
        }
        let last = lines.last ?? ""
        let code = Int(last.prefix(3)) ?? 0
        guard codes.contains(code) else {
            EmailLog.logger.error("SMTP \(code): \(lines.joined(separator: " "), privacy: .public)")
            throw ReplyError(code: code, text: lines.joined(separator: " "))
        }
        EmailLog.logger.debug("SMTP \(code)")
    }

    /// Lines that start with a dot get a second one, and the message ends with CRLF, as SMTP's DATA requires.
    static func dotStuffed(_ message: Data) -> Data {
        var text = String(decoding: message, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
        text = text.components(separatedBy: "\n").map { $0.hasPrefix(".") ? "." + $0 : $0 }.joined(separator: "\r\n")
        if !text.hasSuffix("\r\n") { text += "\r\n" }
        return Data(text.utf8)
    }
}
