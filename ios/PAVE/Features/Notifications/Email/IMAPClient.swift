import Foundation

/// One value in an IMAP response: an atom, a string (quoted or a literal), NIL, or a parenthesised list.
nonisolated indirect enum IMAPValue: Equatable, Sendable {
    case atom(String)
    case string(Data)
    case list([IMAPValue])
    case none

    var text: String? {
        switch self {
        case let .atom(value): value
        case let .string(data): String(decoding: data, as: UTF8.self)
        default: nil
        }
    }

    var data: Data? {
        switch self {
        case let .string(data): data
        case let .atom(value): Data(value.utf8)
        default: nil
        }
    }

    var items: [IMAPValue] {
        if case let .list(values) = self { values } else { [] }
    }
}

/// A response line with its literals, as the server sent it.
nonisolated struct IMAPResponse: Sendable {
    enum Segment: Sendable {
        case text(Data)
        case literal(Data)
    }

    let segments: [Segment]

    var values: [IMAPValue] { IMAPParser.parse(segments) }
}

nonisolated enum IMAPParser {
    private enum Token {
        case open, close
        case value(IMAPValue)
    }

    static func parse(_ segments: [IMAPResponse.Segment]) -> [IMAPValue] {
        var tokens: [Token] = []
        for segment in segments {
            switch segment {
            case let .text(data): tokens += tokenize([UInt8](data))
            case let .literal(data): tokens.append(.value(.string(data)))
            }
        }
        var index = 0
        func build(until close: Bool) -> [IMAPValue] {
            var values: [IMAPValue] = []
            while index < tokens.count {
                let token = tokens[index]
                index += 1
                switch token {
                case .open: values.append(.list(build(until: true)))
                case .close: if close { return values }
                case let .value(value): values.append(value)
                }
            }
            return values
        }
        return build(until: false)
    }

    private static func tokenize(_ bytes: [UInt8]) -> [Token] {
        var tokens: [Token] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            switch byte {
            case 0x20, 0x0D, 0x0A:
                index += 1
            case 0x28:
                tokens.append(.open)
                index += 1
            case 0x29:
                tokens.append(.close)
                index += 1
            case 0x22:
                var value: [UInt8] = []
                index += 1
                while index < bytes.count, bytes[index] != 0x22 {
                    if bytes[index] == 0x5C, index + 1 < bytes.count { index += 1 }
                    value.append(bytes[index])
                    index += 1
                }
                index += 1
                tokens.append(.value(.string(Data(value))))
            default:
                var value: [UInt8] = []
                var depth = 0
                while index < bytes.count {
                    let current = bytes[index]
                    if depth == 0, current == 0x20 || current == 0x28 || current == 0x29 { break }
                    if current == 0x5B { depth += 1 }
                    if current == 0x5D { depth = max(0, depth - 1) }
                    value.append(current)
                    index += 1
                }
                let atom = String(decoding: value, as: UTF8.self)
                tokens.append(.value(atom.uppercased() == "NIL" ? .none : .atom(atom)))
            }
        }
        return tokens
    }

    /// The key-value pairs of a FETCH response: `* 12 FETCH (UID 40 FLAGS (\Seen) BODY[] {…})`.
    static func fetchItems(_ values: [IMAPValue]) -> [String: IMAPValue]? {
        guard values.count >= 4, values[2].text?.uppercased() == "FETCH" else { return nil }
        let pairs = values[3].items
        var result: [String: IMAPValue] = [:]
        var index = 0
        while index + 1 < pairs.count {
            if let key = pairs[index].text?.uppercased() {
                // "BODY[HEADER.FIELDS (FROM …)]" and "BODY[]" are both the message's bytes.
                result[key.hasPrefix("BODY[") ? "BODY" : key] = pairs[index + 1]
            }
            index += 2
        }
        return result
    }
}

/// A small IMAP4rev1 client: log in, find the folders, read headers and messages, set \Seen, add to Verzonden.
final class IMAPClient {
    private let connection: MailConnection
    private var tagNumber = 0

    init(host: String, port: Int = 993) {
        connection = MailConnection(host: host, port: port, implicitTLS: true)
    }

    struct CommandError: Error {
        let status: String
        let text: String
    }

    func open() async throws {
        let greeting = String(decoding: try await connection.readLine(), as: UTF8.self)
        guard greeting.hasPrefix("* OK") || greeting.hasPrefix("* PREAUTH") else { throw EmailError.network }
    }

    func login(user: String, password: String) async throws {
        do {
            _ = try await command("LOGIN \(Self.quote(user)) \(Self.quote(password))")
        } catch is CommandError {
            throw EmailError.wrongPassword
        }
    }

    func logout() async {
        _ = try? await command("LOGOUT")
        connection.close()
    }

    /// Stops at once, also in the middle of IDLE.
    func close() {
        connection.close()
    }

    /// IDLE on the open folder: the server tells right away when mail arrives. True when it did within `seconds`; the
    /// server ends an IDLE after 30 minutes, so this stays below that.
    func idle(for seconds: TimeInterval) async throws -> Bool {
        let tag = nextTag()
        try await connection.write("\(tag) IDLE\r\n")
        while true {
            let line = try await connection.readLine()
            if line.first == 0x2B { break }
            let text = String(decoding: line, as: UTF8.self)
            if text.hasPrefix("\(tag) ") { throw CommandError(status: "NO", text: text) }
        }
        connection.readTimeout = seconds
        defer { connection.readTimeout = 30 }
        var arrived = false
        while !arrived {
            let text = String(decoding: try await connection.readLine(), as: UTF8.self).uppercased()
            arrived = text.hasPrefix("*") && (text.hasSuffix(" EXISTS") || text.hasSuffix(" RECENT"))
        }
        connection.readTimeout = 30
        try await connection.write("DONE\r\n")
        _ = try await readUntilTagged(tag)
        return arrived
    }

    /// Sends one command and returns the untagged responses; throws when the server answers NO or BAD.
    @discardableResult
    func command(_ text: String) async throws -> [IMAPResponse] {
        let tag = nextTag()
        try await connection.write("\(tag) \(text)\r\n")
        return try await readUntilTagged(tag)
    }

    /// APPEND with the message as a literal, after the server's "+" go-ahead.
    func append(_ message: Data, to folder: String, flags: String = "(\\Seen)") async throws {
        let tag = nextTag()
        try await connection.write("\(tag) APPEND \(Self.quote(folder)) \(flags) {\(message.count)}\r\n")
        while true {
            let line = try await connection.readLine()
            if line.first == 0x2B { break }
            let text = String(decoding: line, as: UTF8.self)
            if text.hasPrefix("\(tag) ") { throw CommandError(status: "NO", text: text) }
        }
        try await connection.write(message)
        try await connection.write("\r\n")
        _ = try await readUntilTagged(tag)
    }

    private func nextTag() -> String {
        tagNumber += 1
        return "P\(tagNumber)"
    }

    private func readUntilTagged(_ tag: String) async throws -> [IMAPResponse] {
        var responses: [IMAPResponse] = []
        while true {
            let response = try await readResponse()
            guard case let .text(first)? = response.segments.first else { continue }
            let line = String(decoding: first, as: UTF8.self)
            if line.hasPrefix("\(tag) ") {
                let rest = line.dropFirst(tag.count + 1)
                let status = rest.split(separator: " ").first.map(String.init)?.uppercased() ?? ""
                guard status == "OK" else { throw CommandError(status: status, text: String(rest)) }
                return responses
            }
            if line.hasPrefix("*") { responses.append(response) }
        }
    }

    /// A line, and when it ends in `{n}`, the n bytes after it and the rest of the response.
    private func readResponse() async throws -> IMAPResponse {
        var segments: [IMAPResponse.Segment] = []
        while true {
            let line = try await connection.readLine()
            if let (text, count) = Self.literalMarker(line) {
                segments.append(.text(text))
                segments.append(.literal(try await connection.readBytes(count)))
            } else {
                segments.append(.text(line))
                return IMAPResponse(segments: segments)
            }
        }
    }

    private static func literalMarker(_ line: Data) -> (Data, Int)? {
        guard line.last == 0x7D, let open = line.lastIndex(of: 0x7B) else { return nil }
        let digits = line[line.index(after: open)..<line.index(before: line.endIndex)]
        guard !digits.isEmpty, let count = Int(String(decoding: digits, as: UTF8.self)) else { return nil }
        return (Data(line[line.startIndex..<open]), count)
    }

    static func quote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

extension IMAPClient {
    struct Folder {
        let name: String
        let flags: [String]
    }

    func folders() async throws -> [Folder] {
        try await command("LIST \"\" \"*\"").compactMap { response in
            let values = response.values
            guard values.count >= 5, values[1].text?.uppercased() == "LIST", let name = values[4].text else { return nil }
            return Folder(name: name, flags: values[2].items.compactMap(\.text))
        }
    }

    /// Opens a folder; `readOnly` keeps the server from changing anything, such as \Recent. Returns how many messages it holds.
    @discardableResult
    func open(_ folder: String, readOnly: Bool) async throws -> Int {
        let responses = try await command("\(readOnly ? "EXAMINE" : "SELECT") \(Self.quote(folder))")
        for response in responses {
            let values = response.values
            if values.count >= 3, values[2].text?.uppercased() == "EXISTS", let count = values[1].text.flatMap(Int.init) {
                return count
            }
        }
        return 0
    }

    func fetch(_ set: String, items: String, byUID: Bool) async throws -> [[String: IMAPValue]] {
        try await command("\(byUID ? "UID " : "")FETCH \(set) \(items)").compactMap { IMAPParser.fetchItems($0.values) }
    }
}
